
require 'webrick/httpservlet/abstract.rb'

require 'erb'

module WEBrick
  module HTTPServlet


    class ERBHandler < AbstractServlet


      def initialize(server, name)
        super(server, name)
        @script_filename = name
      end


      def do_GET(req, res)
        unless defined?(ERB)
          @logger.warn "#{self.class}: ERB not defined."
          raise HTTPStatus::Forbidden, "ERBHandler cannot work."
        end
        begin
          data = open(@script_filename){|io| io.read }
          res.body = evaluate(ERB.new(data), req, res)
          res['content-type'] ||=
            HTTPUtils::mime_type(@script_filename, @config[:MimeTypes])
        rescue StandardError
          raise
        rescue Exception => ex
          @logger.error(ex)
          raise HTTPStatus::InternalServerError, ex.message
        end
      end


      alias do_POST do_GET

      private


      def evaluate(erb, servlet_request, servlet_response)
        #nodyna <module_eval-2230> <not yet classified>
        Module.new.module_eval{
          servlet_request.meta_vars
          servlet_request.query
          erb.result(binding)
        }
      end
    end
  end
end
