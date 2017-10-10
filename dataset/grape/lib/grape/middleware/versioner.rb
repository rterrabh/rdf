module Grape
  module Middleware
    module Versioner
      module_function

      def using(strategy)
        case strategy
        when :path
          Path
        when :header
          Header
        when :param
          Param
        when :accept_version_header
          AcceptVersionHeader
        else
          fail Grape::Exceptions::InvalidVersionerOption.new(strategy)
        end
      end
    end
  end
end
