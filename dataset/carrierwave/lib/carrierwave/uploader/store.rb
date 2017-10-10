
module CarrierWave
  module Uploader
    module Store
      extend ActiveSupport::Concern

      include CarrierWave::Uploader::Callbacks
      include CarrierWave::Uploader::Configuration
      include CarrierWave::Uploader::Cache

      def filename
        @filename
      end

      def store_path(for_file=filename)
        File.join([store_dir, full_filename(for_file)].compact)
      end

      def store!(new_file=nil)
        cache!(new_file) if new_file && ((@cache_id != parent_cache_id) || @cache_id.nil?)
        if @file and @cache_id
          with_callbacks(:store, new_file) do
            new_file = storage.store!(@file)
            @file.delete if (delete_tmp_file_after_storage && ! move_to_store)
            delete_cache_id
            @file = new_file
            @cache_id = nil
          end
        end
      end

      def delete_cache_id
        if @cache_id
          path = File.expand_path(File.join(cache_dir, @cache_id), CarrierWave.root)
          begin
            Dir.rmdir(path)
          rescue Errno::ENOENT
          rescue Errno::ENOTDIR
          rescue Errno::ENOTEMPTY, Errno::EEXIST
          end
        end
      end

      def retrieve_from_store!(identifier)
        with_callbacks(:retrieve_from_store, identifier) do
          @file = storage.retrieve!(identifier)
        end
      end

    private

      def full_filename(for_file)
        for_file
      end

      def storage
        @storage ||= self.class.storage.new(self)
      end

    end # Store
  end # Uploader
end # CarrierWave
