require 'action_dispatch/http/response'
require 'delegate'
require 'active_support/json'

module ActionController
  module Live
    class SSE

      WHITELISTED_OPTIONS = %w( retry event id )

      def initialize(stream, options = {})
        @stream = stream
        @options = options
      end

      def close
        @stream.close
      end

      def write(object, options = {})
        case object
        when String
          perform_write(object, options)
        else
          perform_write(ActiveSupport::JSON.encode(object), options)
        end
      end

      private

        def perform_write(json, options)
          current_options = @options.merge(options).stringify_keys

          WHITELISTED_OPTIONS.each do |option_name|
            if (option_value = current_options[option_name])
              @stream.write "#{option_name}: #{option_value}\n"
            end
          end

          message = json.gsub(/\n/, "\ndata: ")
          @stream.write "data: #{message}\n\n"
        end
    end

    class ClientDisconnected < RuntimeError
    end

    class Buffer < ActionDispatch::Response::Buffer #:nodoc:
      include MonitorMixin

      attr_accessor :ignore_disconnect

      def initialize(response)
        @error_callback = lambda { true }
        @cv = new_cond
        @aborted = false
        @ignore_disconnect = false
        super(response, SizedQueue.new(10))
      end

      def write(string)
        unless @response.committed?
          @response.headers["Cache-Control"] = "no-cache"
          @response.headers.delete "Content-Length"
        end

        super

        unless connected?
          @buf.clear

          unless @ignore_disconnect
            raise ClientDisconnected, "client disconnected"
          end
        end
      end

      def each
        @response.sending!
        while str = @buf.pop
          yield str
        end
        @response.sent!
      end

      def close
        synchronize do
          super
          @buf.push nil
          @cv.broadcast
        end
      end

      def abort
        synchronize do
          @aborted = true
          @buf.clear
        end
      end

      def connected?
        !@aborted
      end

      def await_close
        synchronize do
          @cv.wait_until { @closed }
        end
      end

      def on_error(&block)
        @error_callback = block
      end

      def call_on_error
        @error_callback.call
      end
    end

    class Response < ActionDispatch::Response #:nodoc: all
      class Header < DelegateClass(Hash) # :nodoc:
        def initialize(response, header)
          @response = response
          super(header)
        end

        def []=(k,v)
          if @response.committed?
            raise ActionDispatch::IllegalStateError, 'header already sent'
          end

          super
        end

        def merge(other)
          self.class.new @response, __getobj__.merge(other)
        end

        def to_hash
          __getobj__.dup
        end
      end

      private

      def before_committed
        super
        jar = request.cookie_jar
        jar.write self unless committed?
      end

      def before_sending
        super
        request.cookie_jar.commit!
        headers.freeze
      end

      def build_buffer(response, body)
        buf = Live::Buffer.new response
        body.each { |part| buf.write part }
        buf
      end

      def merge_default_headers(original, default)
        Header.new self, super
      end

      def handle_conditional_get!
        super unless committed?
      end
    end

    def process(name)
      t1 = Thread.current
      locals = t1.keys.map { |key| [key, t1[key]] }

      error = nil
      Thread.new {
        t2 = Thread.current
        t2.abort_on_exception = true

        locals.each { |k,v| t2[k] = v }

        begin
          super(name)
        rescue => e
          if @_response.committed?
            begin
              @_response.stream.write(ActionView::Base.streaming_completion_on_exception) if request.format == :html
              @_response.stream.call_on_error
            rescue => exception
              log_error(exception)
            ensure
              log_error(e)
              @_response.stream.close
            end
          else
            error = e
          end
        ensure
          @_response.commit!
        end
      }

      @_response.await_commit
      raise error if error
    end

    def log_error(exception)
      logger = ActionController::Base.logger
      return unless logger

      logger.fatal do
        message = "\n#{exception.class} (#{exception.message}):\n"
        message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
        message << "  " << exception.backtrace.join("\n  ")
        "#{message}\n\n"
      end
    end

    def response_body=(body)
      super
      response.close if response
    end

    def set_response!(request)
      if request.env["HTTP_VERSION"] == "HTTP/1.0"
        super
      else
        @_response         = Live::Response.new
        @_response.request = request
      end
    end
  end
end
