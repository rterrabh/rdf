
class Gem::RequestSet::GemDependencyAPI

  ENGINE_MAP = { # :nodoc:
    :jruby        => %w[jruby],
    :jruby_18     => %w[jruby],
    :jruby_19     => %w[jruby],
    :maglev       => %w[maglev],
    :mri          => %w[ruby],
    :mri_18       => %w[ruby],
    :mri_19       => %w[ruby],
    :mri_20       => %w[ruby],
    :mri_21       => %w[ruby],
    :rbx          => %w[rbx],
    :ruby         => %w[ruby rbx maglev],
    :ruby_18      => %w[ruby rbx maglev],
    :ruby_19      => %w[ruby rbx maglev],
    :ruby_20      => %w[ruby rbx maglev],
    :ruby_21      => %w[ruby rbx maglev],
  }

  mswin     = Gem::Platform.new 'x86-mswin32'
  mswin64   = Gem::Platform.new 'x64-mswin64'
  x86_mingw = Gem::Platform.new 'x86-mingw32'
  x64_mingw = Gem::Platform.new 'x64-mingw32'

  PLATFORM_MAP = { # :nodoc:
    :jruby        => Gem::Platform::RUBY,
    :jruby_18     => Gem::Platform::RUBY,
    :jruby_19     => Gem::Platform::RUBY,
    :maglev       => Gem::Platform::RUBY,
    :mingw        => x86_mingw,
    :mingw_18     => x86_mingw,
    :mingw_19     => x86_mingw,
    :mingw_20     => x86_mingw,
    :mingw_21     => x86_mingw,
    :mri          => Gem::Platform::RUBY,
    :mri_18       => Gem::Platform::RUBY,
    :mri_19       => Gem::Platform::RUBY,
    :mri_20       => Gem::Platform::RUBY,
    :mri_21       => Gem::Platform::RUBY,
    :mswin        => mswin,
    :mswin_18     => mswin,
    :mswin_19     => mswin,
    :mswin_20     => mswin,
    :mswin_21     => mswin,
    :mswin64      => mswin64,
    :mswin64_19   => mswin64,
    :mswin64_20   => mswin64,
    :mswin64_21   => mswin64,
    :rbx          => Gem::Platform::RUBY,
    :ruby         => Gem::Platform::RUBY,
    :ruby_18      => Gem::Platform::RUBY,
    :ruby_19      => Gem::Platform::RUBY,
    :ruby_20      => Gem::Platform::RUBY,
    :ruby_21      => Gem::Platform::RUBY,
    :x64_mingw    => x64_mingw,
    :x64_mingw_20 => x64_mingw,
    :x64_mingw_21 => x64_mingw
  }

  gt_eq_0        = Gem::Requirement.new '>= 0'
  tilde_gt_1_8_0 = Gem::Requirement.new '~> 1.8.0'
  tilde_gt_1_9_0 = Gem::Requirement.new '~> 1.9.0'
  tilde_gt_2_0_0 = Gem::Requirement.new '~> 2.0.0'
  tilde_gt_2_1_0 = Gem::Requirement.new '~> 2.1.0'

  VERSION_MAP = { # :nodoc:
    :jruby        => gt_eq_0,
    :jruby_18     => tilde_gt_1_8_0,
    :jruby_19     => tilde_gt_1_9_0,
    :maglev       => gt_eq_0,
    :mingw        => gt_eq_0,
    :mingw_18     => tilde_gt_1_8_0,
    :mingw_19     => tilde_gt_1_9_0,
    :mingw_20     => tilde_gt_2_0_0,
    :mingw_21     => tilde_gt_2_1_0,
    :mri          => gt_eq_0,
    :mri_18       => tilde_gt_1_8_0,
    :mri_19       => tilde_gt_1_9_0,
    :mri_20       => tilde_gt_2_0_0,
    :mri_21       => tilde_gt_2_1_0,
    :mswin        => gt_eq_0,
    :mswin_18     => tilde_gt_1_8_0,
    :mswin_19     => tilde_gt_1_9_0,
    :mswin_20     => tilde_gt_2_0_0,
    :mswin_21     => tilde_gt_2_1_0,
    :mswin64      => gt_eq_0,
    :mswin64_19   => tilde_gt_1_9_0,
    :mswin64_20   => tilde_gt_2_0_0,
    :mswin64_21   => tilde_gt_2_1_0,
    :rbx          => gt_eq_0,
    :ruby         => gt_eq_0,
    :ruby_18      => tilde_gt_1_8_0,
    :ruby_19      => tilde_gt_1_9_0,
    :ruby_20      => tilde_gt_2_0_0,
    :ruby_21      => tilde_gt_2_1_0,
    :x64_mingw    => gt_eq_0,
    :x64_mingw_20 => tilde_gt_2_0_0,
    :x64_mingw_21 => tilde_gt_2_1_0,
  }

  WINDOWS = { # :nodoc:
    :mingw        => :only,
    :mingw_18     => :only,
    :mingw_19     => :only,
    :mingw_20     => :only,
    :mingw_21     => :only,
    :mri          => :never,
    :mri_18       => :never,
    :mri_19       => :never,
    :mri_20       => :never,
    :mri_21       => :never,
    :mswin        => :only,
    :mswin_18     => :only,
    :mswin_19     => :only,
    :mswin_20     => :only,
    :mswin_21     => :only,
    :mswin64      => :only,
    :mswin64_19   => :only,
    :mswin64_20   => :only,
    :mswin64_21   => :only,
    :rbx          => :never,
    :ruby         => :never,
    :ruby_18      => :never,
    :ruby_19      => :never,
    :ruby_20      => :never,
    :ruby_21      => :never,
    :x64_mingw    => :only,
    :x64_mingw_20 => :only,
    :x64_mingw_21 => :only,
  }


  attr_reader :dependencies


  attr_reader :git_set # :nodoc:


  attr_reader :requires # :nodoc:


  attr_reader :vendor_set # :nodoc:


  attr_accessor :without_groups # :nodoc:


  def initialize set, path
    @set = set
    @path = path

    @current_groups     = nil
    @current_platforms  = nil
    @current_repository = nil
    @dependencies       = {}
    @default_sources    = true
    @git_set            = @set.git_set
    @git_sources        = {}
    @installing         = false
    @requires           = Hash.new { |h, name| h[name] = [] }
    @vendor_set         = @set.vendor_set
    @gem_sources        = {}
    @without_groups     = []

    git_source :github do |repo_name|
      repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include? "/"

      "git://github.com/#{repo_name}.git"
    end

    git_source :bitbucket do |repo_name|
      repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include? "/"

      user, = repo_name.split "/", 2

      "https://#{user}@bitbucket.org/#{repo_name}.git"
    end
  end


  def add_dependencies groups, dependencies # :nodoc:
    return unless (groups & @without_groups).empty?

    dependencies.each do |dep|
      @set.gem dep.name, *dep.requirement
    end
  end

  private :add_dependencies


  def find_gemspec name, path # :nodoc:
    glob = File.join path, "#{name}.gemspec"

    spec_files = Dir[glob]

    case spec_files.length
    when 1 then
      spec_file = spec_files.first

      spec = Gem::Specification.load spec_file

      return spec if spec

      raise ArgumentError, "invalid gemspec #{spec_file}"
    when 0 then
      raise ArgumentError, "no gemspecs found at #{Dir.pwd}"
    else
      raise ArgumentError,
        "found multiple gemspecs at #{Dir.pwd}, " +
        "use the name: option to specify the one you want"
    end
  end


  def installing= installing # :nodoc:
    @installing = installing
  end


  def load
    #nodyna <instance_eval-2292> <IEV COMPLEX (block execution)>
    instance_eval File.read(@path).untaint, @path, 1

    self
  end


  def gem name, *requirements
    options = requirements.pop if requirements.last.kind_of?(Hash)
    options ||= {}

    options[:git] = @current_repository if @current_repository

    source_set = false

    source_set ||= gem_path       name, options
    source_set ||= gem_git        name, options
    source_set ||= gem_git_source name, options

    duplicate = @dependencies.include? name

    @dependencies[name] =
      if requirements.empty? and not source_set then
        nil
      elsif source_set then
        '!'
      else
        requirements
      end

    return unless gem_platforms options

    groups = gem_group name, options

    return unless (groups & @without_groups).empty?

    pin_gem_source name, :default unless source_set

    gem_requires name, options

    if duplicate then
      warn <<-WARNING
Gem dependencies file #{@path} requires #{name} more than once.
      WARNING
    end

    @set.gem name, *requirements
  end


  def gem_git name, options # :nodoc:
    if gist = options.delete(:gist) then
      options[:git] = "https://gist.github.com/#{gist}.git"
    end

    return unless repository = options.delete(:git)

    pin_gem_source name, :git, repository

    reference = nil
    reference ||= options.delete :ref
    reference ||= options.delete :branch
    reference ||= options.delete :tag
    reference ||= 'master'

    submodules = options.delete :submodules

    @git_set.add_git_gem name, repository, reference, submodules

    true
  end

  private :gem_git


  def gem_git_source name, options # :nodoc:
    return unless git_source = (@git_sources.keys & options.keys).last

    source_callback = @git_sources[git_source]
    source_param = options.delete git_source

    git_url = source_callback.call source_param

    options[:git] = git_url

    gem_git name, options

    true
  end

  private :gem_git_source


  def gem_group name, options # :nodoc:
    g = options.delete :group
    all_groups  = g ? Array(g) : []

    groups = options.delete :groups
    all_groups |= groups if groups

    all_groups |= @current_groups if @current_groups

    all_groups
  end

  private :gem_group


  def gem_path name, options # :nodoc:
    return unless directory = options.delete(:path)

    pin_gem_source name, :path, directory

    @vendor_set.add_vendor_gem name, directory

    true
  end

  private :gem_path


  def gem_platforms options # :nodoc:
    platform_names = Array(options.delete :platform)
    platform_names.concat Array(options.delete :platforms)
    platform_names.concat @current_platforms if @current_platforms

    return true if platform_names.empty?

    platform_names.any? do |platform_name|
      raise ArgumentError, "unknown platform #{platform_name.inspect}" unless
        platform = PLATFORM_MAP[platform_name]

      next false unless Gem::Platform.match platform

      if engines = ENGINE_MAP[platform_name] then
        next false unless engines.include? Gem.ruby_engine
      end

      case WINDOWS[platform_name]
      when :only then
        next false unless Gem.win_platform?
      when :never then
        next false if Gem.win_platform?
      end

      VERSION_MAP[platform_name].satisfied_by? Gem.ruby_version
    end
  end

  private :gem_platforms


  def gem_requires name, options # :nodoc:
    if options.include? :require then
      if requires = options.delete(:require) then
        @requires[name].concat Array requires
      end
    else
      @requires[name] << name
    end
  end

  private :gem_requires


  def git repository
    @current_repository = repository

    yield

  ensure
    @current_repository = nil
  end


  def git_source name, &callback
    @git_sources[name] = callback
  end


  def gem_deps_file # :nodoc:
    File.basename @path
  end


  def gemspec options = {}
    name              = options.delete(:name) || '{,*}'
    path              = options.delete(:path) || '.'
    development_group = options.delete(:development_group) || :development

    spec = find_gemspec name, path

    groups = gem_group spec.name, {}

    self_dep = Gem::Dependency.new spec.name, spec.version

    add_dependencies groups, [self_dep]
    add_dependencies groups, spec.runtime_dependencies

    @dependencies[spec.name] = '!'

    spec.dependencies.each do |dep|
      @dependencies[dep.name] = dep.requirement
    end

    groups << development_group

    add_dependencies groups, spec.development_dependencies

    gem_requires spec.name, options
  end


  def group *groups
    @current_groups = groups

    yield

  ensure
    @current_groups = nil
  end


  def pin_gem_source name, type = :default, source = nil
    source_description =
      case type
      when :default then '(default)'
      when :path    then "path: #{source}"
      when :git     then "git: #{source}"
      else               '(unknown)'
      end

    raise ArgumentError,
      "duplicate source #{source_description} for gem #{name}" if
        @gem_sources.fetch(name, source) != source

    @gem_sources[name] = source
  end

  private :pin_gem_source


  def platform *platforms
    @current_platforms = platforms

    yield

  ensure
    @current_platforms = nil
  end


  alias :platforms :platform


  def ruby version, options = {}
    engine         = options[:engine]
    engine_version = options[:engine_version]

    raise ArgumentError,
          'you must specify engine_version along with the ruby engine' if
            engine and not engine_version

    return true if @installing

    unless RUBY_VERSION == version then
      message = "Your Ruby version is #{RUBY_VERSION}, " +
                "but your #{gem_deps_file} requires #{version}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine and engine != Gem.ruby_engine then
      message = "Your ruby engine is #{Gem.ruby_engine}, " +
                "but your #{gem_deps_file} requires #{engine}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine_version then
      #nodyna <const_get-2293> <CG COMPLEX (change-prone variable)>
      my_engine_version = Object.const_get "#{Gem.ruby_engine.upcase}_VERSION"

      if engine_version != my_engine_version then
        message =
          "Your ruby engine version is #{Gem.ruby_engine} #{my_engine_version}, " +
          "but your #{gem_deps_file} requires #{engine} #{engine_version}"

        raise Gem::RubyVersionMismatch, message
      end
    end

    return true
  end


  def source url
    Gem.sources.clear if @default_sources

    @default_sources = false

    Gem.sources << url
  end


  Gem::RequestSet::GemDepedencyAPI = self # :nodoc:

end

