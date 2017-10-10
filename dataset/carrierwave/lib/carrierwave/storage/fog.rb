
require "fog"

module CarrierWave
  module Storage

    class Fog < Abstract
      class << self
        def connection_cache
          @connection_cache ||= {}
        end
      end

      def store!(file)
        f = CarrierWave::Storage::Fog::File.new(uploader, self, uploader.store_path)
        f.store(file)
        f
      end

      def retrieve!(identifier)
        CarrierWave::Storage::Fog::File.new(uploader, self, uploader.store_path(identifier))
      end

      def connection
        @connection ||= begin
          options = credentials = uploader.fog_credentials
          self.class.connection_cache[credentials] ||= ::Fog::Storage.new(options)
        end
      end

      class File
        include CarrierWave::Utilities::Uri

        attr_reader :path

        def attributes
          file.attributes
        end

        def authenticated_url(options = {})
          if ['AWS', 'Google', 'Rackspace', 'OpenStack'].include?(@uploader.fog_credentials[:provider])
            local_directory = connection.directories.new(:key => @uploader.fog_directory)
            local_file = local_directory.files.new(:key => path)
            if @uploader.fog_credentials[:provider] == "AWS"
              local_file.url(::Fog::Time.now + @uploader.fog_authenticated_url_expiration, options)
            elsif ['Rackspace', 'OpenStack'].include?(@uploader.fog_credentials[:provider])
              connection.get_object_https_url(@uploader.fog_directory, path, ::Fog::Time.now + @uploader.fog_authenticated_url_expiration)
            else
              local_file.url(::Fog::Time.now + @uploader.fog_authenticated_url_expiration)
            end
          else
            nil
          end
        end

        def content_type
          @content_type || file.content_type
        end

        def content_type=(new_content_type)
          @content_type = new_content_type
        end

        def delete
          directory.files.new(:key => path).destroy
        end

        def extension
          path_elements = path.split('.')
          path_elements.last if path_elements.size > 1
        end

        def headers
          location = caller.first
          warning = "[yellow][WARN] headers is deprecated, use attributes instead[/]"
          warning << " [light_black](#{location})[/]"
          Formatador.display_line(warning)
          attributes
        end

        def initialize(uploader, base, path)
          @uploader, @base, @path = uploader, base, path
        end

        def read
          file.body
        end

        def size
          file.content_length
        end

        def exists?
          !!directory.files.head(path)
        end

        def store(new_file)
          fog_file = new_file.to_file
          @content_type ||= new_file.content_type
          @file = directory.files.create({
            :body         => fog_file ? fog_file : new_file.read,
            :content_type => @content_type,
            :key          => path,
            :public       => @uploader.fog_public
          }.merge(@uploader.fog_attributes))
          fog_file.close if fog_file && !fog_file.closed?
          true
        end

        def public_url
          encoded_path = encode_path(path)
          if host = @uploader.asset_host
            if host.respond_to? :call
              "#{host.call(self)}/#{encoded_path}"
            else
              "#{host}/#{encoded_path}"
            end
          else
            case @uploader.fog_credentials[:provider]
            when 'AWS'
              if @uploader.fog_credentials.has_key?(:endpoint)
                "#{@uploader.fog_credentials[:endpoint]}/#{@uploader.fog_directory}/#{encoded_path}"
              else
                protocol = @uploader.fog_use_ssl_for_aws ? "https" : "http"
                if @uploader.fog_directory.to_s =~ /^(?:[a-z]|\d(?!\d{0,2}(?:\d{1,3}){3}$))(?:[a-z0-9\.]|(?![\-])|\-(?![\.])){1,61}[a-z0-9]$/
                  "#{protocol}://#{@uploader.fog_directory}.s3.amazonaws.com/#{encoded_path}"
                else
                  "#{protocol}://s3.amazonaws.com/#{@uploader.fog_directory}/#{encoded_path}"
                end
              end
            when 'Google'
              "https://commondatastorage.googleapis.com/#{@uploader.fog_directory}/#{encoded_path}"
            else
              directory.files.new(:key => path).public_url
            end
          end
        end

        def url(options = {})
          if !@uploader.fog_public
            authenticated_url(options)
          else
            public_url
          end
        end

        def filename(options = {})
          if file_url = url(options)
            URI.decode(file_url).gsub(/.*\/(.*?$)/, '\1').split('?').first
          end
        end

      private

        def connection
          @base.connection
        end

        def directory
          @directory ||= begin
            connection.directories.new(
              :key    => @uploader.fog_directory,
              :public => @uploader.fog_public
            )
          end
        end

        def file
          @file ||= directory.files.head(path)
        end

      end

    end # Fog

  end # Storage
end # CarrierWave
