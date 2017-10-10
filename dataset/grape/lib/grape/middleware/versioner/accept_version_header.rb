require 'grape/middleware/base'

module Grape
  module Middleware
    module Versioner
      class AcceptVersionHeader < Base
        def before
          potential_version = (env[Grape::Http::Headers::HTTP_ACCEPT_VERSION] || '').strip

          if strict?
            if potential_version.empty?
              throw :error, status: 406, headers: error_headers, message: 'Accept-Version header must be set.'
            end
          end

          unless potential_version.empty?
            unless versions.any? { |v| v.to_s == potential_version }
              throw :error, status: 406, headers: error_headers, message: 'The requested version is not supported.'
            end

            env['api.version'] = potential_version
          end
        end

        private

        def versions
          options[:versions] || []
        end

        def strict?
          options[:version_options] && options[:version_options][:strict]
        end

        def cascade?
          if options[:version_options] && options[:version_options].key?(:cascade)
            !!options[:version_options][:cascade]
          else
            true
          end
        end

        def error_headers
          cascade? ? { Grape::Http::Headers::X_CASCADE => 'pass' } : {}
        end
      end
    end
  end
end
