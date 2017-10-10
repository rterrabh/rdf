require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "etc"
require "fileutils"

class FPM::Package::Puppet < FPM::Package
  def architecture
    case @architecture
    when nil, "native"
      @architecture = %x{uname -m}.chomp
    end
    return @architecture
  end # def architecture

  def generate_specfile(builddir)
    paths = []
    logger.info("PWD: #{File.join(builddir, unpack_data_to)}")
    fileroot = File.join(builddir, unpack_data_to)
    Dir.chdir(fileroot) do
      Find.find(".") do |p|
        next if p == "."
        paths << p
      end
    end
    logger.info(paths[-1])
    manifests = %w{package.pp package/remove.pp}

    ::Dir.mkdir(File.join(builddir, "manifests"))
    manifests.each do |manifest|
      dir = File.join(builddir, "manifests", File.dirname(manifest))
      logger.info("manifests targeting: #{dir}")
      ::Dir.mkdir(dir) if !File.directory?(dir)

      File.open(File.join(builddir, "manifests", manifest), "w") do |f|
        logger.info("manifest: #{f.path}")
        template = template(File.join("puppet", "#{manifest}.erb"))
        ::Dir.chdir(fileroot) do
          f.puts template.result(binding)
        end
      end
    end
  end # def generate_specfile

  def unpack_data_to
    "files"
  end

  def build!(params)
    self.scripts.each do |name, path|
      case name
        when "pre-install"
        when "post-install"
        when "pre-uninstall"
        when "post-uninstall"
      end # case name
    end # self.scripts.each

    if File.exists?(params[:output])
      logger.error("Puppet module directory '#{params[:output]}' already " \
                    "exists. Delete it or choose another output (-p flag)")
    end

    ::Dir.mkdir(params[:output])
    builddir = ::Dir.pwd

    Find.find("files", "manifests") do |path|
      logger.info("Copying path: #{path}")
      if File.directory?(path)
        ::Dir.mkdir(File.join(params[:output], path))
      else
        FileUtils.cp(path, File.join(params[:output], path))
      end
    end
  end # def build!

  def default_output
    name
  end # def default_output

  def puppetsort(hash)
    return hash.to_a
  end # def puppetsort

  def uid2user(uid)
    begin
      pwent = Etc.getpwuid(uid)
      return pwent.name
    rescue ArgumentError => e
      logger.warn("Failed to find username for uid #{uid}")
      return uid.to_s
    end
  end # def uid2user

  def gid2group(gid)
    begin
      grent = Etc.getgrgid(gid)
      return grent.name
    rescue ArgumentError => e
      logger.warn("Failed to find group for gid #{gid}")
      return gid.to_s
    end
  end # def uid2user
end # class FPM::Target::Puppet
