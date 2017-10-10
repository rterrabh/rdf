require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

class FPM::Package::NPM < FPM::Package
  class << self
    include FPM::Util
  end
  option "--bin", "NPM_EXECUTABLE",
    "The path to the npm executable you wish to run.", :default => "npm"

  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "node"

  option "--registry", "NPM_REGISTRY",
    "The npm registry to use instead of the default."

  private
  def input(package)
    settings = {
      "cache" => build_path("npm_cache"),
      "loglevel" => "warn",
      "global" => "true"
    }

    settings["registry"] = attributes[:npm_registry] if attributes[:npm_registry_given?]
    set_default_prefix unless attributes[:prefix_given?]

    settings["prefix"] = staging_path(attributes[:prefix])
    FileUtils.mkdir_p(settings["prefix"])

    npm_flags = []
    settings.each do |key, value|
      logger.debug("Configuring npm", key => value)
      npm_flags += [ "--#{key}", value ]
    end

    install_args = [
      attributes[:npm_bin],
      "install",
     (version ? "#{package}@#{version}" : package)
    ]

    install_args += npm_flags

    safesystem(*install_args)

    npm_ls_out = safesystemout(attributes[:npm_bin], "ls", "--json", "--long", *npm_flags)
    npm_ls = JSON.parse(npm_ls_out)
    name, info = npm_ls["dependencies"].first

    self.name = [attributes[:npm_package_name_prefix], name].join("-")
    self.version = info.fetch("version", "0.0.0")

    if info.include?("repository")
      self.url = info["repository"]["url"]
    else
      self.url = "https://npmjs.org/package/#{self.name}"
    end

    self.description = info["description"]
    self.vendor = "Unknown <unknown@unknown.unknown>"
    if info.include?("author")
      author_info = info["author"]
      if author_info.respond_to? :fetch
        self.vendor = sprintf("%s <%s>", author_info.fetch("name", "unknown"),
                              author_info.fetch("email", "unknown@unknown.unknown"))
      else
        self.vendor = author_info unless author_info == ""
      end
    end

  end

  def set_default_prefix
    attributes[:prefix] = self.class.default_prefix
    attributes[:prefix_given?] = true
  end

  def self.default_prefix
    npm_prefix = safesystemout("npm", "prefix", "-g").chomp
    if npm_prefix.count("\n") > 0
      raise FPM::InvalidPackageConfiguration, "`npm prefix -g` returned unexpected output."
    elsif !File.directory?(npm_prefix)
      raise FPM::InvalidPackageConfiguration, "`npm prefix -g` returned a non-existent directory"
    end
    logger.info("Setting default npm install prefix", :prefix => npm_prefix)
    npm_prefix
  end

  public(:input)
end # class FPM::Package::NPM
