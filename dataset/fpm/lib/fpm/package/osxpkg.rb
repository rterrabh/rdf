require "fpm/package"
require "fpm/util"
require "fileutils"
require "fpm/package/dir"
require 'tempfile'  # stdlib
require 'pathname'  # stdlib
require 'rexml/document'  # stdlib

class FPM::Package::OSXpkg < FPM::Package

  SCRIPT_MAP = {
    :before_install     => "preinstall",
    :after_install      => "postinstall",
  } unless defined?(SCRIPT_MAP)

  POSTINSTALL_ACTIONS = [ "logout", "restart", "shutdown" ]
  OWNERSHIP_OPTIONS = ["recommended", "preserve", "preserve-other"]

  option "--identifier-prefix", "IDENTIFIER_PREFIX",
    "Reverse domain prefix prepended to package identifier, " \
    "ie. 'org.great.my'. If this is omitted, the identifer " \
    "will be the package name."
  option "--payload-free", :flag, "Define no payload, assumes use of script options.",
    :default => false
  option "--ownership", "OWNERSHIP",
    "--ownership option passed to pkgbuild. Defaults to 'recommended'. " \
    "See pkgbuild(1).", :default => 'recommended' do |value|
    if !OWNERSHIP_OPTIONS.include?(value)
      raise ArgumentError, "osxpkg-ownership value of '#{value}' is invalid. " \
        "Must be one of #{OWNERSHIP_OPTIONS.join(", ")}"
    end
    value
  end

  option "--postinstall-action", "POSTINSTALL_ACTION",
    "Post-install action provided in package metadata. " \
    "Optionally one of '#{POSTINSTALL_ACTIONS.join("', '")}'." do |value|
    if !POSTINSTALL_ACTIONS.include?(value)
      raise ArgumentError, "osxpkg-postinstall-action value of '#{value}' is invalid. " \
        "Must be one of #{POSTINSTALL_ACTIONS.join(", ")}"
    end
    value
  end

  dont_obsolete_paths = []
  option "--dont-obsolete", "DONT_OBSOLETE_PATH",
    "A file path for which to 'dont-obsolete' in the built PackageInfo. " \
    "Can be specified multiple times." do |path|
      dont_obsolete_paths << path
    end

  private
  def identifier
    identifier = name.dup
    if self.attributes[:osxpkg_identifier_prefix]
      identifier.insert(0, "#{self.attributes[:osxpkg_identifier_prefix]}.")
    end
    identifier
  end # def identifier

  def scripts_path(path=nil)
    @scripts_path ||= build_path("Scripts")
    FileUtils.mkdir(@scripts_path) if !File.directory?(@scripts_path)

    if path.nil?
      return @scripts_path
    else
      return File.join(@scripts_path, path)
    end
  end # def scripts_path

  def write_scripts
    SCRIPT_MAP.each do |scriptname, filename|
      next unless script?(scriptname)

      with(scripts_path(filename)) do |pkgscript|
        logger.info("Writing pkg script", :source => filename, :target => pkgscript)
        File.write(pkgscript, script(scriptname))
        File.chmod(0755, pkgscript)
      end
    end
  end # def write_scripts

  def pkginfo_template_path
    pkginfo_template = Tempfile.open("fpm-PackageInfo")
    pkginfo_data = template("osxpkg.erb").result(binding)
    pkginfo_template.write(pkginfo_data)
    pkginfo_template.close
    pkginfo_template.path
  end # def write_pkginfo_template

  def extract_info(package)
    with(build_path("expand")) do |path|
      doc = REXML::Document.new File.open(File.join(path, "PackageInfo"))
      pkginfo_elem = doc.elements["pkg-info"]
      identifier = pkginfo_elem.attribute("identifier").value
      self.version = pkginfo_elem.attribute("version").value
      self.name = identifier.split(".").last
      logger.info("inferring name #{self.name} from pkg-id #{identifier}")
    end
  end # def extract_info

  def input(input_path)
    expand_dir = File.join(build_path, "expand")
    safesystem("pkgutil --expand #{input_path} #{expand_dir}")

    extract_info(input_path)

    safesystem("tar -xz -f #{expand_dir}/Payload -C #{staging_path}")
  end # def input

  def output(output_path)
    output_check(output_path)

    temp_info = pkginfo_template_path

    args = ["--identifier", identifier,
            "--info", temp_info,
            "--version", version.to_s,
            "--ownership", attributes[:osxpkg_ownership]]

    if self.attributes[:osxpkg_payload_free?]
      args << "--nopayload"
    else
      args += ["--root", staging_path]
    end

    if attributes[:before_install_given?] or attributes[:after_install_given?]
      write_scripts
      args += ["--scripts", scripts_path]
    end
    args << output_path

    safesystem("pkgbuild", *args)
    FileUtils.remove_file(temp_info)
  end # def output

  def to_s(format=nil)
    return super("NAME-VERSION.pkg") if format.nil?
    return super(format)
  end # def to_s

  public(:input, :output, :identifier, :to_s)

end # class FPM::Package::OSXpkg
