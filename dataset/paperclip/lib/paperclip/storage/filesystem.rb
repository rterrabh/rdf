module Paperclip
  module Storage
    module Filesystem
      def self.extended base
      end

      def exists?(style_name = default_style)
        if original_filename
          File.exist?(path(style_name))
        else
          false
        end
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style_name, file|
          FileUtils.mkdir_p(File.dirname(path(style_name)))
          begin
            FileUtils.mv(file.path, path(style_name))
          rescue SystemCallError
            File.open(path(style_name), "wb") do |new_file|
              while chunk = file.read(16 * 1024)
                new_file.write(chunk)
              end
            end
          end
          unless @options[:override_file_permissions] == false
            resolved_chmod = (@options[:override_file_permissions] &~ 0111) || (0666 &~ File.umask)
            FileUtils.chmod( resolved_chmod, path(style_name) )
          end
          file.rewind
        end

        after_flush_writes # allows attachment to clean up temp files

        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            FileUtils.rm(path) if File.exist?(path)
          rescue Errno::ENOENT => e
          end
          begin
            while(true)
              path = File.dirname(path)
              FileUtils.rmdir(path)
              break if File.exist?(path) # Ruby 1.9.2 does not raise if the removal failed.
            end
          rescue Errno::EEXIST, Errno::ENOTEMPTY, Errno::ENOENT, Errno::EINVAL, Errno::ENOTDIR, Errno::EACCES
          rescue SystemCallError => e
            log("There was an unexpected error while deleting directories: #{e.class}")
          end
        end
        @queued_for_delete = []
      end

      def copy_to_local_file(style, local_dest_path)
        FileUtils.cp(path(style), local_dest_path)
      end
    end

  end
end
