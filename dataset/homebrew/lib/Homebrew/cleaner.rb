class Cleaner
  def initialize(f)
    @f = f
  end

  def clean
    ObserverPathnameExtension.reset_counts!

    observe_file_removal @f.lib/"charset.alias"

    [@f.bin, @f.sbin, @f.lib].each { |d| clean_dir(d) if d.exist? }

    info_dir_file = @f.info + "dir"
    if info_dir_file.file? && !@f.skip_clean?(info_dir_file)
      observe_file_removal info_dir_file
    end

    prune
  end

  private

  def observe_file_removal(path)
    path.extend(ObserverPathnameExtension).unlink if path.exist?
  end

  def prune
    dirs = []
    symlinks = []
    @f.prefix.find do |path|
      if path == @f.libexec || @f.skip_clean?(path)
        Find.prune
      elsif path.symlink?
        symlinks << path
      elsif path.directory?
        dirs << path
      end
    end

    dirs.reverse_each do |d|
      if d.children.empty?
        puts "rmdir: #{d} (empty)" if ARGV.verbose?
        d.rmdir
      end
    end

    symlinks.reverse_each do |s|
      s.unlink unless s.resolved_path_exists?
    end
  end

  def clean_dir(d)
    d.find do |path|
      path.extend(ObserverPathnameExtension)

      Find.prune if @f.skip_clean? path

      if path.symlink? || path.directory?
        next
      elsif path.extname == ".la"
        path.unlink
      else
        perms = if path.mach_o_executable? || path.text_executable?
          0555
        else
          0444
        end
        if ARGV.debug?
          old_perms = path.stat.mode & 0777
          if perms != old_perms
            puts "Fixing #{path} permissions from #{old_perms.to_s(8)} to #{perms.to_s(8)}"
          end
        end
        path.chmod perms
      end
    end
  end
end
