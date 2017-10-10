require 'grape/middleware/base'

module Grape
  module Middleware
    module Versioner
      class Header < Base
        def before
          header = rack_accept_header

          if strict?
            if header.qvalues.empty?
              fail Grape::Exceptions::InvalidAcceptHeader.new('Accept header must be set.', error_headers)
            end
            header.qvalues.reject! do |media_type, _|
              Rack::Accept::Header.parse_media_type(media_type).find { |s| s == '*' }
            end
            if header.qvalues.empty?
              fail Grape::Exceptions::InvalidAcceptHeader.new('Accept header must not contain ranges ("*").',
                                                              error_headers)
            end
          end

          media_type = header.best_of available_media_types

          if media_type
            type, subtype = Rack::Accept::Header.parse_media_type media_type
            env['api.type']    = type
            env['api.subtype'] = subtype

            if /\Avnd\.([a-z0-9*.]+)(?:-([a-z0-9*\-.]+))?(?:\+([a-z0-9*\-.+]+))?\z/ =~ subtype
              env['api.vendor']  = Regexp.last_match[1]
              env['api.version'] = Regexp.last_match[2]
              env['api.format']  = Regexp.last_match[3]  # weird that Grape::Middleware::Formatter also does this
            end
          elsif strict?
            fail Grape::Exceptions::InvalidAcceptHeader.new('406 Not Acceptable', error_headers)
          elsif header.values.all? { |header_value| has_vendor?(header_value) || version?(header_value) }
            fail Grape::Exceptions::InvalidAcceptHeader.new('API vendor or version not found.', error_headers)
          end
        end

        private

        def available_media_types
          available_media_types = []

          content_types.each do |extension, _media_type|
            versions.reverse_each do |version|
              available_media_types += ["application/vnd.#{vendor}-#{version}+#{extension}", "application/vnd.#{vendor}-#{version}"]
            end
            available_media_types << "application/vnd.#{vendor}+#{extension}"
          end

          available_media_types << "application/vnd.#{vendor}"

          content_types.each do |_, media_type|
            available_media_types << media_type
          end

          available_media_types.flatten
        end

        def rack_accept_header
          Rack::Accept::MediaType.new env[Grape::Http::Headers::HTTP_ACCEPT]
        rescue RuntimeError => e
          raise Grape::Exceptions::InvalidAcceptHeader.new(e.message, error_headers)
        end

        def versions
          options[:versions] || []
        end

        def vendor
          options[:version_options] && options[:version_options][:vendor]
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

        def has_vendor?(media_type)
          _, subtype = Rack::Accept::Header.parse_media_type media_type
          subtype[/\Avnd\.[a-z0-9*.]+/]
        end

        def version?(media_type)
          _, subtype = Rack::Accept::Header.parse_media_type media_type
          subtype[/\Avnd\.[a-z0-9*.]+-[a-z0-9*\-.]+/]
        end
      end
    end
  end
end
