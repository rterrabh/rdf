require 'grape/middleware/base'

module Grape
  module Middleware
    module Versioner
      class Path < Base
        def default_options
          {
            pattern: /.*/i
          }
        end

        def before
          path = env[Grape::Http::Headers::PATH_INFO].dup

          if prefix && path.index(prefix) == 0
            path.sub!(prefix, '')
            path = Rack::Mount::Utils.normalize_path(path)
          end

          pieces = path.split('/')
          potential_version = pieces[1]
          if potential_version =~ options[:pattern]
            if options[:versions] && !options[:versions].find { |v| v.to_s == potential_version }
              throw :error, status: 404, message: '404 API Version Not Found'
            end
            env['api.version'] = potential_version
          end
        end

        private

        def prefix
          Rack::Mount::Utils.normalize_path(options[:prefix].to_s) if options[:prefix]
        end
      end
    end
  end
end
