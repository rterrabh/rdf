
module CarrierWave
  module Storage

    class File < Abstract

      def store!(file)
        path = ::File.expand_path(uploader.store_path, uploader.root)
        if uploader.move_to_store
          file.move_to(path, uploader.permissions, uploader.directory_permissions)
        else
          file.copy_to(path, uploader.permissions, uploader.directory_permissions)
        end
      end

      def retrieve!(identifier)
        path = ::File.expand_path(uploader.store_path(identifier), uploader.root)
        CarrierWave::SanitizedFile.new(path)
      end

    end # File
  end # Storage
end # CarrierWave
