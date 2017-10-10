class Gem::PathSupport
  attr_reader :home

  attr_reader :path

  attr_reader :spec_cache_dir # :nodoc:

  def initialize(env=ENV)
    @env = env

    @home     = env["GEM_HOME"] || ENV["GEM_HOME"] || Gem.default_dir

    if File::ALT_SEPARATOR then
      @home   = @home.gsub(File::ALT_SEPARATOR, File::SEPARATOR)
    end

    self.path = env["GEM_PATH"] || ENV["GEM_PATH"]

    @spec_cache_dir =
      env["GEM_SPEC_CACHE"] || ENV["GEM_SPEC_CACHE"] ||
        Gem.default_spec_cache_dir

    @spec_cache_dir = @spec_cache_dir.dup.untaint
  end

  private


  def home=(home)
    @home = home.to_s
  end


  def path=(gpaths)

    gem_path = []

    gpaths ||= (ENV['GEM_PATH'] || "").empty? ? nil : ENV["GEM_PATH"]

    if gpaths
      if gpaths.kind_of?(Array)
        gem_path = gpaths.dup
      else
        gem_path = gpaths.split(Gem.path_separator)
      end

      if File::ALT_SEPARATOR then
        gem_path.map! do |this_path|
          this_path.gsub File::ALT_SEPARATOR, File::SEPARATOR
        end
      end

      gem_path << @home
    else
      gem_path = Gem.default_path + [@home]

      if defined?(APPLE_GEM_HOME)
        gem_path << APPLE_GEM_HOME
      end
    end

    @path = gem_path.uniq
  end
end
