module Grape
  module Parser
    module Xml
      class << self
        def call(object, _env)
          MultiXml.parse(object)
        rescue MultiXml::ParseError
          raise Grape::Exceptions::InvalidMessageBody, 'application/xml'
        end
      end
    end
  end
end
