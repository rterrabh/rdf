require 'action_controller/metal/exceptions'

module ActionController #:nodoc:
  module DataStreaming
    extend ActiveSupport::Concern

    include ActionController::Rendering

    DEFAULT_SEND_FILE_TYPE        = 'application/octet-stream'.freeze #:nodoc:
    DEFAULT_SEND_FILE_DISPOSITION = 'attachment'.freeze #:nodoc:

    protected
      def send_file(path, options = {}) #:doc:
        raise MissingFile, "Cannot read file #{path}" unless File.file?(path) and File.readable?(path)

        options[:filename] ||= File.basename(path) unless options[:url_based_filename]
        send_file_headers! options

        self.status = options[:status] || 200
        self.content_type = options[:content_type] if options.key?(:content_type)
        self.response_body = FileBody.new(path)
      end

      class FileBody #:nodoc:
        attr_reader :to_path

        def initialize(path)
          @to_path = path
        end

        def each
          File.open(to_path, 'rb') do |file|
            while chunk = file.read(16384)
              yield chunk
            end
          end
        end
      end

      def send_data(data, options = {}) #:doc:
        send_file_headers! options
        render options.slice(:status, :content_type).merge(:text => data)
      end

    private
      def send_file_headers!(options)
        type_provided = options.has_key?(:type)

        content_type = options.fetch(:type, DEFAULT_SEND_FILE_TYPE)
        raise ArgumentError, ":type option required" if content_type.nil?

        if content_type.is_a?(Symbol)
          extension = Mime[content_type]
          raise ArgumentError, "Unknown MIME type #{options[:type]}" unless extension
          self.content_type = extension
        else
          if !type_provided && options[:filename]
            content_type = Mime::Type.lookup_by_extension(File.extname(options[:filename]).downcase.delete('.')) || content_type
          end
          self.content_type = content_type
        end

        disposition = options.fetch(:disposition, DEFAULT_SEND_FILE_DISPOSITION)
        unless disposition.nil?
          disposition  = disposition.to_s
          disposition += %(; filename="#{options[:filename]}") if options[:filename]
          headers['Content-Disposition'] = disposition
        end

        headers['Content-Transfer-Encoding'] = 'binary'

        response.sending_file = true

        response.cache_control[:public] ||= false
      end
  end
end
