require 'fileutils'

class File
  def self.atomic_write(file_name, temp_dir = Dir.tmpdir)
    require 'tempfile' unless defined?(Tempfile)
    require 'fileutils' unless defined?(FileUtils)

    temp_file = Tempfile.new(basename(file_name), temp_dir)
    temp_file.binmode
    yield temp_file
    temp_file.close

    if File.exist?(file_name)
      old_stat = stat(file_name)
    else
      old_stat = probe_stat_in(dirname(file_name))
    end

    FileUtils.mv(temp_file.path, file_name)

    begin
      chown(old_stat.uid, old_stat.gid, file_name)
      chmod(old_stat.mode, file_name)
    rescue Errno::EPERM, Errno::EACCES
    end
  end

  def self.probe_stat_in(dir) #:nodoc:
    basename = [
      '.permissions_check',
      Thread.current.object_id,
      Process.pid,
      rand(1000000)
    ].join('.')

    file_name = join(dir, basename)
    FileUtils.touch(file_name)
    stat(file_name)
  ensure
    FileUtils.rm_f(file_name) if file_name
  end
end
