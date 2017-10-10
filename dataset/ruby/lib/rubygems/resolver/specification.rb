
class Gem::Resolver::Specification


  attr_reader :dependencies


  attr_reader :name


  attr_reader :platform


  attr_reader :set


  attr_reader :source


  attr_reader :spec


  attr_reader :version


  def initialize
    @dependencies = nil
    @name         = nil
    @platform     = nil
    @set          = nil
    @source       = nil
    @version      = nil
  end


  def fetch_development_dependencies # :nodoc:
  end


  def full_name
    "#{@name}-#{@version}"
  end


  def install options = {}
    require 'rubygems/installer'

    destination = options[:install_dir] || Gem.dir

    Gem.ensure_gem_subdirectories destination

    gem = source.download spec, destination

    installer = Gem::Installer.new gem, options

    yield installer if block_given?

    @spec = installer.install
  end


  def installable_platform?
    Gem::Platform.match spec.platform
  end

  def local? # :nodoc:
    false
  end
end

