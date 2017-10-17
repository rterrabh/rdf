module Paperclip
  module Storage

    module S3
      def self.extended base
        begin
          require 'aws-sdk'
        rescue LoadError => e
          e.message << " (You may need to install the aws-sdk gem)"
          raise e
        end unless defined?(AWS::Core)

        if defined?(AWS::Core::LogFormatter)
          #nodyna <class_eval-689> <CE MODERATE (define methods)>
          AWS::Core::LogFormatter.class_eval do
            def summarize_hash(hash)
              hash.map { |key, value| ":#{key}=>#{summarize_value(value)}".force_encoding('UTF-8') }.sort.join(',')
            end
          end
        elsif defined?(AWS::Core::ClientLogging)
          #nodyna <class_eval-690> <CE MODERATE (define methods)>
          AWS::Core::ClientLogging.class_eval do
            def sanitize_hash(hash)
              hash.map { |key, value| "#{sanitize_value(key)}=>#{sanitize_value(value)}".force_encoding('UTF-8') }.sort.join(',')
            end
          end
        end

        #nodyna <instance_eval-691> <IEV COMPLEX (private access)>
        base.instance_eval do
          @s3_options     = @options[:s3_options]     || {}
          @s3_permissions = set_permissions(@options[:s3_permissions])
          @s3_protocol    = @options[:s3_protocol]    ||
            Proc.new do |style, attachment|
              permission  = (@s3_permissions[style.to_s.to_sym] || @s3_permissions[:default])
              permission  = permission.call(attachment, style) if permission.respond_to?(:call)
              (permission == :public_read) ? 'http' : 'https'
            end
          @s3_metadata = @options[:s3_metadata] || {}
          @s3_headers = {}
          merge_s3_headers(@options[:s3_headers], @s3_headers, @s3_metadata)

          @s3_storage_class = set_storage_class(@options[:s3_storage_class])

          @s3_server_side_encryption = :aes256
          if @options[:s3_server_side_encryption].blank?
            @s3_server_side_encryption = false
          end
          if @s3_server_side_encryption
            @s3_server_side_encryption = @options[:s3_server_side_encryption]
          end

          unless @options[:url].to_s.match(/\A:s3.*url\Z/) || @options[:url] == ":asset_host"
            @options[:path] = path_option.gsub(/:url/, @options[:url]).gsub(/\A:rails_root\/public\/system/, '')
            @options[:url]  = ":s3_path_url"
          end
          @options[:url] = @options[:url].inspect if @options[:url].is_a?(Symbol)

          @http_proxy = @options[:http_proxy] || nil
        end

        Paperclip.interpolates(:s3_alias_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_alias}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_alias_url
        Paperclip.interpolates(:s3_path_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.s3_host_name}/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_path_url
        Paperclip.interpolates(:s3_domain_url) do |attachment, style|
          "#{attachment.s3_protocol(style, true)}//#{attachment.bucket_name}.#{attachment.s3_host_name}/#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :s3_domain_url
        Paperclip.interpolates(:asset_host) do |attachment, style|
          "#{attachment.path(style).gsub(%r{\A/}, "")}"
        end unless Paperclip::Interpolations.respond_to? :asset_host
      end

      def expiring_url(time = 3600, style_name = default_style)
        if path(style_name)
          base_options = { :expires => time, :secure => use_secure_protocol?(style_name) }
          s3_object(style_name).url_for(:read, base_options.merge(s3_url_options)).to_s
        else
          url(style_name)
        end
      end

      def s3_credentials
        @s3_credentials ||= parse_credentials(@options[:s3_credentials])
      end

      def s3_host_name
        host_name = @options[:s3_host_name]
        host_name = host_name.call(self) if host_name.is_a?(Proc)

        host_name || s3_credentials[:s3_host_name] || "s3.amazonaws.com"
      end

      def s3_host_alias
        @s3_host_alias = @options[:s3_host_alias]
        @s3_host_alias = @s3_host_alias.call(self) if @s3_host_alias.respond_to?(:call)
        @s3_host_alias
      end

      def s3_url_options
        s3_url_options = @options[:s3_url_options] || {}
        s3_url_options = s3_url_options.call(instance) if s3_url_options.respond_to?(:call)
        s3_url_options
      end

      def bucket_name
        @bucket = @options[:bucket] || s3_credentials[:bucket]
        @bucket = @bucket.call(self) if @bucket.respond_to?(:call)
        @bucket or raise ArgumentError, "missing required :bucket option"
      end

      def s3_interface
        @s3_interface ||= begin
          config = { :s3_endpoint => s3_host_name }

          if using_http_proxy?

            proxy_opts = { :host => http_proxy_host }
            proxy_opts[:port] = http_proxy_port if http_proxy_port
            if http_proxy_user
              userinfo = http_proxy_user.to_s
              userinfo += ":#{http_proxy_password}" if http_proxy_password
              proxy_opts[:userinfo] = userinfo
            end
            config[:proxy_uri] = URI::HTTP.build(proxy_opts)
          end

          [:access_key_id, :secret_access_key, :credential_provider].each do |opt|
            config[opt] = s3_credentials[opt] if s3_credentials[opt]
          end

          obtain_s3_instance_for(config.merge(@s3_options))
        end
      end

      def obtain_s3_instance_for(options)
        instances = (Thread.current[:paperclip_s3_instances] ||= {})
        instances[options] ||= AWS::S3.new(options)
      end

      def s3_bucket
        @s3_bucket ||= s3_interface.buckets[bucket_name]
      end

      def s3_object style_name = default_style
        s3_bucket.objects[path(style_name).sub(%r{\A/},'')]
      end

      def using_http_proxy?
        !!@http_proxy
      end

      def http_proxy_host
        using_http_proxy? ? @http_proxy[:host] : nil
      end

      def http_proxy_port
        using_http_proxy? ? @http_proxy[:port] : nil
      end

      def http_proxy_user
        using_http_proxy? ? @http_proxy[:user] : nil
      end

      def http_proxy_password
        using_http_proxy? ? @http_proxy[:password] : nil
      end

      def set_permissions permissions
        permissions = { :default => permissions } unless permissions.respond_to?(:merge)
        permissions.merge :default => (permissions[:default] || :public_read)
      end

      def set_storage_class(storage_class)
        storage_class = {:default => storage_class} unless storage_class.respond_to?(:merge)
        storage_class
      end

      def parse_credentials creds
        creds = creds.respond_to?('call') ? creds.call(self) : creds
        creds = find_credentials(creds).stringify_keys
        (creds[RailsEnvironment.get] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        if original_filename
          s3_object(style).exists?
        else
          false
        end
      rescue AWS::Errors::Base => e
        false
      end

      def s3_permissions(style = default_style)
        s3_permissions = @s3_permissions[style] || @s3_permissions[:default]
        s3_permissions = s3_permissions.call(self, style) if s3_permissions.respond_to?(:call)
        s3_permissions
      end

      def s3_storage_class(style = default_style)
        @s3_storage_class[style] || @s3_storage_class[:default]
      end

      def s3_protocol(style = default_style, with_colon = false)
        protocol = @s3_protocol
        protocol = protocol.call(style, self) if protocol.respond_to?(:call)

        if with_colon && !protocol.empty?
          "#{protocol}:"
        else
          protocol.to_s
        end
      end

      def create_bucket
        s3_interface.buckets.create(bucket_name)
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
        retries = 0
          begin
            log("saving #{path(style)}")
            acl = @s3_permissions[style] || @s3_permissions[:default]
            acl = acl.call(self, style) if acl.respond_to?(:call)
            write_options = {
              :content_type => file.content_type,
              :acl => acl
            }

            storage_class = s3_storage_class(style)
            write_options.merge!(:storage_class => storage_class) if storage_class

            if @s3_server_side_encryption
              write_options[:server_side_encryption] = @s3_server_side_encryption
            end

            style_specific_options = styles[style]

            if style_specific_options
              merge_s3_headers( style_specific_options[:s3_headers], @s3_headers, @s3_metadata) if style_specific_options[:s3_headers]
              @s3_metadata.merge!(style_specific_options[:s3_metadata]) if style_specific_options[:s3_metadata]
            end

            write_options[:metadata] = @s3_metadata unless @s3_metadata.empty?
            write_options.merge!(@s3_headers)

            s3_object(style).write(file, write_options)
          rescue AWS::S3::Errors::NoSuchBucket
            create_bucket
            retry
          rescue AWS::S3::Errors::SlowDown
            retries += 1
            if retries <= 5
              sleep((2 ** retries) * 0.5)
              retry
            else
              raise
            end
          ensure
            file.rewind
          end
        end

        after_flush_writes # allows attachment to clean up temp files

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            s3_bucket.objects[path.sub(%r{\A/},'')].delete
          rescue AWS::Errors::Base => e
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        log("copying #{path(style)} to local file #{local_dest_path}")
        ::File.open(local_dest_path, 'wb') do |local_file|
          s3_object(style).read do |chunk|
            local_file.write(chunk)
          end
        end
      rescue AWS::Errors::Base => e
        warn("#{e} - cannot copy #{path(style)} to local file #{local_dest_path}")
        false
      end

      private

      def find_credentials creds
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        when NilClass
          {}
        else
          raise ArgumentError, "Credentials given are not a path, file, proc, or hash."
        end
      end

      def use_secure_protocol?(style_name)
        s3_protocol(style_name) == "https"
      end

      def merge_s3_headers(http_headers, s3_headers, s3_metadata)
        return if http_headers.nil?
        http_headers = http_headers.call(instance) if http_headers.respond_to?(:call)
        http_headers.inject({}) do |headers,(name,value)|
          case name.to_s
          when /\Ax-amz-meta-(.*)/i
            s3_metadata[$1.downcase] = value
          else
            s3_headers[name.to_s.downcase.sub(/\Ax-amz-/,'').tr("-","_").to_sym] = value
          end
        end
      end
    end
  end
end
