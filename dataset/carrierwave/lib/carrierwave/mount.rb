
module CarrierWave

  module Mount

    def uploaders
      @uploaders ||= superclass.respond_to?(:uploaders) ? superclass.uploaders.dup : {}
    end

    def uploader_options
      @uploader_options ||= superclass.respond_to?(:uploader_options) ? superclass.uploader_options.dup : {}
    end

    def uploader_option(column, option)
      if uploader_options[column].has_key?(option)
        uploader_options[column][option]
      else
        #nodyna <send-2665> <not yet classified>
        uploaders[column].send(option)
      end
    end

    def mount_uploader(column, uploader=nil, options={}, &block)
      include CarrierWave::Mount::Extension

      uploader = build_uploader(uploader, &block)
      uploaders[column.to_sym] = uploader
      uploader_options[column.to_sym] = options

      #nodyna <class_eval-2666> <not yet classified>
      class_eval <<-RUBY, __FILE__, __LINE__+1
        def #{column}; super; end
        def #{column}=(new_file); super; end
      RUBY

      mod = Module.new
      include mod
      #nodyna <class_eval-2667> <not yet classified>
      mod.class_eval <<-RUBY, __FILE__, __LINE__+1

        def #{column}
          _mounter(:#{column}).uploader
        end

        def #{column}=(new_file)
          _mounter(:#{column}).cache(new_file)
        end

        def #{column}?
          _mounter(:#{column}).present?
        end

        def #{column}_url(*args)
          _mounter(:#{column}).url(*args)
        end

        def #{column}_cache
          _mounter(:#{column}).cache_name
        end

        def #{column}_cache=(cache_name)
          _mounter(:#{column}).cache_name = cache_name
        end

        def remote_#{column}_url
          _mounter(:#{column}).remote_url
        end

        def remote_#{column}_url=(url)
          _mounter(:#{column}).remote_url = url
        end

        def remove_#{column}
          _mounter(:#{column}).remove
        end

        def remove_#{column}!
          _mounter(:#{column}).remove!
        end

        def remove_#{column}=(value)
          _mounter(:#{column}).remove = value
        end

        def remove_#{column}?
          _mounter(:#{column}).remove?
        end

        def store_#{column}!
          _mounter(:#{column}).store!
        end

        def #{column}_integrity_error
          _mounter(:#{column}).integrity_error
        end

        def #{column}_processing_error
          _mounter(:#{column}).processing_error
        end

        def #{column}_download_error
          _mounter(:#{column}).download_error
        end

        def write_#{column}_identifier
          _mounter(:#{column}).write_identifier
        end

        def #{column}_identifier
          _mounter(:#{column}).identifier
        end

        def store_previous_model_for_#{column}
          serialization_column = _mounter(:#{column}).serialization_column

          #nodyna <send-2668> <not yet classified>
          if #{column}.remove_previously_stored_files_after_update && send(:"\#{serialization_column}_changed?")
            @previous_model_for_#{column} ||= self.find_previous_model_for_#{column}
          end
        end

        def find_previous_model_for_#{column}
          self.class.find(to_key.first)
        end

        def remove_previously_stored_#{column}
          if @previous_model_for_#{column} && @previous_model_for_#{column}.#{column}.path != #{column}.path
            @previous_model_for_#{column}.#{column}.remove!
            @previous_model_for_#{column} = nil
          end
        end

        def mark_remove_#{column}_false
          _mounter(:#{column}).remove = false
        end

      RUBY
    end

    private

    def build_uploader(uploader, &block)
      return uploader if uploader && !block_given?

      uploader = Class.new(uploader || CarrierWave::Uploader::Base)
      #nodyna <const_set-2669> <not yet classified>
      const_set("Uploader#{uploader.object_id}".gsub('-', '_'), uploader)

      if block_given?
        #nodyna <class_eval-2670> <not yet classified>
        uploader.class_eval(&block)
        uploader.recursively_apply_block_to_versions(&block)
      end

      uploader
    end

    module Extension

      def read_uploader(column); end

      def write_uploader(column, identifier); end

    private

      def _mounter(column)
        return Mounter.new(self, column) if frozen?
        @_mounters ||= {}
        @_mounters[column] ||= Mounter.new(self, column)
      end

    end # Extension

    class Mounter #:nodoc:
      attr_reader :column, :record, :remote_url, :integrity_error, :processing_error, :download_error
      attr_accessor :remove

      def initialize(record, column, options={})
        @record = record
        @column = column
        @options = record.class.uploader_options[column]
      end

      def write_identifier
        return if record.frozen?

        if remove?
          record.write_uploader(serialization_column, nil)
        elsif uploader.identifier.present?
          record.write_uploader(serialization_column, uploader.identifier)
        end
      end

      def identifier
        record.read_uploader(serialization_column)
      end

      def uploader
        @uploader ||= record.class.uploaders[column].new(record, column)
        @uploader.retrieve_from_store!(identifier) if @uploader.blank? && identifier.present?

        @uploader
      end

      def cache(new_file)
        uploader.cache!(new_file)
        @integrity_error = nil
        @processing_error = nil
      rescue CarrierWave::IntegrityError => e
        @integrity_error = e
        raise e unless option(:ignore_integrity_errors)
      rescue CarrierWave::ProcessingError => e
        @processing_error = e
        raise e unless option(:ignore_processing_errors)
      end

      def cache_name
        uploader.cache_name
      end

      def cache_name=(cache_name)
        uploader.retrieve_from_cache!(cache_name) unless uploader.cached?
      rescue CarrierWave::InvalidParameter
      end

      def remote_url=(url)
        return if url.blank?

        @remote_url = url
        @download_error = nil
        @integrity_error = nil

        uploader.download!(url)

      rescue CarrierWave::DownloadError => e
        @download_error = e
        raise e unless option(:ignore_download_errors)
      rescue CarrierWave::ProcessingError => e
        @processing_error = e
        raise e unless option(:ignore_processing_errors)
      rescue CarrierWave::IntegrityError => e
        @integrity_error = e
        raise e unless option(:ignore_integrity_errors)
      end

      def store!
        return if uploader.blank?

        if remove?
          uploader.remove!
        else
          uploader.store!
        end
      end

      def url(*args)
        uploader.url(*args)
      end

      def blank?
        uploader.blank?
      end

      def remove?
        remove.present? && remove !~ /\A0|false$\z/
      end

      def remove!
        uploader.remove!
      end

      def serialization_column
        option(:mount_on) || column
      end

      attr_accessor :uploader_options

    private

      def option(name)
        self.uploader_options ||= {}
        self.uploader_options[name] ||= record.class.uploader_option(column, name)
      end

    end # Mounter

  end # Mount
end # CarrierWave
