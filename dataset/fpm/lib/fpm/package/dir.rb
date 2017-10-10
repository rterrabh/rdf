require "fpm/package"
require "fpm/util"
require "backports"
require "fileutils"
require "find"
require "socket"

class FPM::Package::Dir < FPM::Package
  private

  def input(path)
    chdir = attributes[:chdir] || "."

    if path =~ /.=./ && !File.exists?(chdir == '.' ? path : File.join(chdir, path))
      origin, destination = path.split("=", 2)

      if File.directory?(origin) && origin[-1,1] == "/"
        chdir = chdir == '.' ? origin : File.join(chdir, origin)
        source = "."
      else
        origin_dir = File.dirname(origin)
        chdir = chdir == '.' ? origin_dir : File.join(chdir, origin_dir)
        source = File.basename(origin)
      end
    else
      source, destination = path, "/"
    end

    if attributes[:prefix]
      destination = File.join(attributes[:prefix], destination)
    end

    destination = File.join(staging_path, destination)

    logger["method"] = "input"
    begin
      ::Dir.chdir(chdir) do
        begin
          clone(source, destination)
        rescue Errno::ENOENT => e
          raise FPM::InvalidPackageConfiguration,
            "Cannot package the path '#{File.join(chdir, source)}', does it exist?"
        end
      end
    rescue Errno::ENOENT => e
      raise FPM::InvalidPackageConfiguration,
        "Cannot chdir to '#{chdir}'. Does it exist?"
    end

    self.license = "unknown"
    self.vendor = [ENV["USER"], Socket.gethostname].join("@")
  ensure
    logger.remove("method")
  end # def input

  def output(output_path)
    output_check(output_path)

    output_path = File.expand_path(output_path)
    ::Dir.chdir(staging_path) do
      logger["method"] = "output"
      clone(".", output_path)
    end
  ensure
    logger.remove("method")
  end # def output

  private
  def clone(source, destination)
    logger.debug("Cloning path", :source => source, :destination => destination)
    if File.expand_path(source) == File.expand_path(::Dir.tmpdir)
      raise FPM::InvalidPackageConfiguration,
        "A source directory cannot be the root of your temporary " \
        "directory (#{::Dir.tmpdir}). fpm uses the temporary directory " \
        "to stage files during packaging, so this setting would have " \
        "caused fpm to loop creating staging directories and copying " \
        "them into your package! Oops! If you are confused, maybe you could " \
        "check your TMPDIR or TEMPDIR environment variables?"
    end

    fileinfo = File.lstat(source)
    if fileinfo.file? && !File.directory?(destination)
      if destination[-1,1] == "/"
        copy(source, File.join(destination, source))
      else
        copy(source, destination)
      end
    elsif fileinfo.symlink?
      copy(source, File.join(destination, source))
    else
      Find.find(source) do |path|
        target = File.join(destination, path)
        copy(path, target)
      end
    end
  end # def clone

  def copy(source, destination)
    logger.debug("Copying path", :source => source, :destination => destination)
    directory = File.dirname(destination)
    dstat = File.stat(directory) rescue nil
    if dstat.nil?
      FileUtils.mkdir_p(directory)
    elsif dstat.directory?
    else
      readable_path = directory.gsub(staging_path, "")
      logger.error("You wanted to copy a file into a directory, but that's not a directory, it's a file!", :path => readable_path, :stat => dstat)
      raise FPM::InvalidPackageConfiguration, "Tried to treat #{readable_path} like a directory, but it's a file!"
    end

    if File.directory?(source)
      if !File.symlink?(source)
        logger.debug("Creating", :directory => destination)
        if !File.directory?(destination)
          FileUtils.mkdir(destination)
        end
      else
        logger.debug("Copying symlinked directory", :source => source,
                      :destination => destination)
        FileUtils.copy_entry(source, destination)
      end
    else
      begin
        logger.debug("Linking", :source => source, :destination => destination)
        File.link(source, destination)
      rescue Errno::ENOENT, Errno::EXDEV, Errno::EPERM
        logger.debug("Copying", :source => source, :destination => destination)
        copy_entry(source, destination)
      rescue Errno::EEXIST
        sane_path = destination.gsub(staging_path, "")
        logger.error("Cannot copy file, the destination path is probably a directory and I attempted to write a file.", :path => sane_path, :staging => staging_path)
      end
    end

    copy_metadata(source, destination)
  end # def copy

  public(:input, :output)
end # class FPM::Package::Dir
