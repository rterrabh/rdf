require 'grape/middleware/base'

module Grape
  module Middleware
    module Versioner
      class Param < Base
        def default_options
          {
            parameter: 'apiver'
          }
        end

        def before
          paramkey = options[:parameter]
          potential_version = Rack::Utils.parse_nested_query(env[Grape::Http::Headers::QUERY_STRING])[paramkey]
          unless potential_version.nil?
            if options[:versions] && !options[:versions].find { |v| v.to_s == potential_version }
              throw :error, status: 404, message: '404 API Version Not Found', headers: { Grape::Http::Headers::X_CASCADE => 'pass' }
            end
            env['api.version'] = potential_version
            env['rack.request.query_hash'].delete(paramkey) if env.key? 'rack.request.query_hash'
          end
        end
      end
    end
  end
end
