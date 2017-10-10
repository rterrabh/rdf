
require 'webrick/httpservlet/abstract.rb'

module WEBrick
  module HTTPServlet


    class ProcHandler < AbstractServlet
      def get_instance(server, *options)
        self
      end

      def initialize(proc)
        @proc = proc
      end

      def do_GET(request, response)
        @proc.call(request, response)
      end

      alias do_POST do_GET
    end

  end
end
