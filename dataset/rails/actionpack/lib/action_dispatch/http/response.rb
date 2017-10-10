require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/string/filters'
require 'active_support/deprecation'
require 'action_dispatch/http/filter_redirect'
require 'monitor'

module ActionDispatch # :nodoc:
  class Response
    attr_accessor :request

    attr_reader :status

    attr_writer :sending_file

    attr_accessor :header

    alias_method :headers=, :header=
    alias_method :headers,  :header

    delegate :[], :[]=, :to => :@header
    delegate :each, :to => :@stream

    attr_reader   :content_type

    attr_accessor :charset

    CONTENT_TYPE = "Content-Type".freeze
    SET_COOKIE   = "Set-Cookie".freeze
    LOCATION     = "Location".freeze
    NO_CONTENT_CODES = [204, 304]

    cattr_accessor(:default_charset) { "utf-8" }
    cattr_accessor(:default_headers)

    include Rack::Response::Helpers
    include ActionDispatch::Http::FilterRedirect
    include ActionDispatch::Http::Cache::Response
    include MonitorMixin

    class Buffer # :nodoc:
      def initialize(response, buf)
        @response = response
        @buf      = buf
        @closed   = false
      end

      def write(string)
        raise IOError, "closed stream" if closed?

        @response.commit!
        @buf.push string
      end

      def each(&block)
        @response.sending!
        x = @buf.each(&block)
        @response.sent!
        x
      end

      def abort
      end

      def close
        @response.commit!
        @closed = true
      end

      def closed?
        @closed
      end
    end

    attr_reader :stream

    def initialize(status = 200, header = {}, body = [], options = {})
      super()

      default_headers = options.fetch(:default_headers, self.class.default_headers)
      header = merge_default_headers(header, default_headers)

      self.body, self.header, self.status = body, header, status

      @sending_file = false
      @blank        = false
      @cv           = new_cond
      @committed    = false
      @sending      = false
      @sent         = false
      @content_type = nil
      @charset      = nil

      if content_type = self[CONTENT_TYPE]
        type, charset = content_type.split(/;\s*charset=/)
        @content_type = Mime::Type.lookup(type)
        @charset = charset || self.class.default_charset
      end

      prepare_cache_control!

      yield self if block_given?
    end

    def await_commit
      synchronize do
        @cv.wait_until { @committed }
      end
    end

    def await_sent
      synchronize { @cv.wait_until { @sent } }
    end

    def commit!
      synchronize do
        before_committed
        @committed = true
        @cv.broadcast
      end
    end

    def sending!
      synchronize do
        before_sending
        @sending = true
        @cv.broadcast
      end
    end

    def sent!
      synchronize do
        @sent = true
        @cv.broadcast
      end
    end

    def sending?;   synchronize { @sending };   end
    def committed?; synchronize { @committed }; end
    def sent?;      synchronize { @sent };      end

    def status=(status)
      @status = Rack::Utils.status_code(status)
    end

    def content_type=(content_type)
      @content_type = content_type.to_s
    end

    def response_code
      @status
    end

    def code
      @status.to_s
    end

    def message
      Rack::Utils::HTTP_STATUS_CODES[@status]
    end
    alias_method :status_message, :message

    def body
      strings = []
      each { |part| strings << part.to_s }
      strings.join
    end

    EMPTY = " "

    def body=(body)
      @blank = true if body == EMPTY

      if body.respond_to?(:to_path)
        @stream = body
      else
        synchronize do
          @stream = build_buffer self, munge_body_object(body)
        end
      end
    end

    def body_parts
      parts = []
      @stream.each { |x| parts << x }
      parts
    end

    def set_cookie(key, value)
      ::Rack::Utils.set_cookie_header!(header, key, value)
    end

    def delete_cookie(key, value={})
      ::Rack::Utils.delete_cookie_header!(header, key, value)
    end

    def location
      headers[LOCATION]
    end
    alias_method :redirect_url, :location

    def location=(url)
      headers[LOCATION] = url
    end

    def close
      stream.close if stream.respond_to?(:close)
    end

    def abort
      if stream.respond_to?(:abort)
        stream.abort
      elsif stream.respond_to?(:close)
        stream.close
      end
    end

    def to_a
      rack_response @status, @header.to_hash
    end
    alias prepare! to_a

    def to_ary
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        `ActionDispatch::Response#to_ary` no longer performs implicit conversion
        to an array. Please use `response.to_a` instead, or a splat like `status,
        headers, body = *response`.
      MSG

      to_a
    end

    def cookies
      cookies = {}
      if header = self[SET_COOKIE]
        header = header.split("\n") if header.respond_to?(:to_str)
        header.each do |cookie|
          if pair = cookie.split(';').first
            key, value = pair.split("=").map { |v| Rack::Utils.unescape(v) }
            cookies[key] = value
          end
        end
      end
      cookies
    end

  private

    def before_committed
    end

    def before_sending
    end

    def merge_default_headers(original, default)
      default.respond_to?(:merge) ? default.merge(original) : original
    end

    def build_buffer(response, body)
      Buffer.new response, body
    end

    def munge_body_object(body)
      body.respond_to?(:each) ? body : [body]
    end

    def assign_default_content_type_and_charset!(headers)
      return if headers[CONTENT_TYPE].present?

      @content_type ||= Mime::HTML
      @charset      ||= self.class.default_charset unless @charset == false

      type = @content_type.to_s.dup
      type << "; charset=#{@charset}" if append_charset?

      headers[CONTENT_TYPE] = type
    end

    def append_charset?
      !@sending_file && @charset != false
    end

    class RackBody
      def initialize(response)
        @response = response
      end

      def each(*args, &block)
        @response.each(*args, &block)
      end

      def close
        @response.abort
      end

      def body
        @response.body
      end

      def respond_to?(method, include_private = false)
        if method.to_s == 'to_path'
          @response.stream.respond_to?(method)
        else
          super
        end
      end

      def to_path
        @response.stream.to_path
      end

      def to_ary
        nil
      end
    end

    def rack_response(status, header)
      assign_default_content_type_and_charset!(header)
      handle_conditional_get!

      header[SET_COOKIE] = header[SET_COOKIE].join("\n") if header[SET_COOKIE].respond_to?(:join)

      if NO_CONTENT_CODES.include?(@status)
        header.delete CONTENT_TYPE
        [status, header, []]
      else
        [status, header, RackBody.new(self)]
      end
    end
  end
end
