module CarrierWave

  module Uploader
    module Configuration
      extend ActiveSupport::Concern

      included do
        class_attribute :_storage, :instance_writer => false

        add_config :root
        add_config :base_path
        add_config :asset_host
        add_config :permissions
        add_config :directory_permissions
        add_config :storage_engines
        add_config :store_dir
        add_config :cache_dir
        add_config :enable_processing
        add_config :ensure_multipart_form
        add_config :delete_tmp_file_after_storage
        add_config :move_to_cache
        add_config :move_to_store
        add_config :remove_previously_stored_files_after_update

        add_config :fog_attributes
        add_config :fog_credentials
        add_config :fog_directory
        add_config :fog_public
        add_config :fog_authenticated_url_expiration
        add_config :fog_use_ssl_for_aws

        add_config :ignore_integrity_errors
        add_config :ignore_processing_errors
        add_config :ignore_download_errors
        add_config :validate_integrity
        add_config :validate_processing
        add_config :validate_download
        add_config :mount_on

        reset_config
      end

      module ClassMethods

        def storage(storage = nil)
          if storage
            #nodyna <eval-2674> <not yet classified>
            self._storage = storage.is_a?(Symbol) ? eval(storage_engines[storage]) : storage
          end
          _storage
        end
        alias_method :storage=, :storage

        def add_config(name)
          #nodyna <class_eval-2675> <not yet classified>
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.eager_load_fog(fog_credentials)
              Fog::Storage.new(fog_credentials) if fog_credentials.present?
            end

            def self.#{name}(value=nil)
              @#{name} = value if value
              eager_load_fog(value) if value && '#{name}' == 'fog_credentials'
              return @#{name} if self.object_id == #{self.object_id} || defined?(@#{name})
              name = superclass.#{name}
              return nil if name.nil? && !instance_variable_defined?("@#{name}")
              @#{name} = name && !name.is_a?(Module) && !name.is_a?(Symbol) && !name.is_a?(Numeric) && !name.is_a?(TrueClass) && !name.is_a?(FalseClass) ? name.dup : name
            end

            def self.#{name}=(value)
              eager_load_fog(value) if '#{name}' == 'fog_credentials'
              @#{name} = value
            end

            def #{name}=(value)
              self.class.eager_load_fog(value) if '#{name}' == 'fog_credentials'
              @#{name} = value
            end

            def #{name}
              value = @#{name} if instance_variable_defined?(:@#{name})
              value = self.class.#{name} unless instance_variable_defined?(:@#{name})
              if value.instance_of?(Proc)
                value.arity >= 1 ? value.call(self) : value.call
              else 
                value
              end
            end
          RUBY
        end

        def configure
          yield self
        end

        def reset_config
          configure do |config|
            config.permissions = 0644
            config.directory_permissions = 0755
            config.storage_engines = {
              :file => "CarrierWave::Storage::File",
              :fog  => "CarrierWave::Storage::Fog"
            }
            config.storage = :file
            config.fog_attributes = {}
            config.fog_credentials = {}
            config.fog_public = true
            config.fog_authenticated_url_expiration = 600
            config.fog_use_ssl_for_aws = true
            config.store_dir = 'uploads'
            config.cache_dir = 'uploads/tmp'
            config.delete_tmp_file_after_storage = true
            config.move_to_cache = false
            config.move_to_store = false
            config.remove_previously_stored_files_after_update = true
            config.ignore_integrity_errors = true
            config.ignore_processing_errors = true
            config.ignore_download_errors = true
            config.validate_integrity = true
            config.validate_processing = true
            config.validate_download = true
            config.root = lambda { CarrierWave.root }
            config.base_path = CarrierWave.base_path
            config.enable_processing = true
            config.ensure_multipart_form = true
          end
        end
      end

    end
  end
end

