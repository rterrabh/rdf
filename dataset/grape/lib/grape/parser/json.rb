module Grape
  module Parser
    module Json
      class << self
        def call(object, _env)
          MultiJson.load(object)
        rescue MultiJson::ParseError
          raise Grape::Exceptions::InvalidMessageBody, 'application/json'
        end
      end
    end
  end
end
