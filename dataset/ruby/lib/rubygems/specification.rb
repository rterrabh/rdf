

require 'rubygems/version'
require 'rubygems/requirement'
require 'rubygems/platform'
require 'rubygems/deprecate'
require 'rubygems/basic_specification'
require 'rubygems/stub_specification'
require 'rubygems/util/stringio'


class Gem::Specification < Gem::BasicSpecification



  NONEXISTENT_SPECIFICATION_VERSION = -1


  CURRENT_SPECIFICATION_VERSION = 4 # :nodoc:


  SPECIFICATION_VERSION_HISTORY = { # :nodoc:
    -1 => ['(RubyGems versions up to and including 0.7 did not have versioned specifications)'],
    1  => [
      'Deprecated "test_suite_file" in favor of the new, but equivalent, "test_files"',
      '"test_file=x" is a shortcut for "test_files=[x]"'
    ],
    2  => [
      'Added "required_rubygems_version"',
      'Now forward-compatible with future versions',
    ],
    3 => [
       'Added Fixnum validation to the specification_version'
    ],
    4 => [
      'Added sandboxed freeform metadata to the specification version.'
    ]
  }

  MARSHAL_FIELDS = { # :nodoc:
    -1 => 16,
     1 => 16,
     2 => 16,
     3 => 17,
     4 => 18,
  }

  today = Time.now.utc
  TODAY = Time.utc(today.year, today.month, today.day) # :nodoc:

  LOAD_CACHE = {} # :nodoc:

  private_constant :LOAD_CACHE if defined? private_constant



  @@required_attributes = [:rubygems_version,
                           :specification_version,
                           :name,
                           :version,
                           :date,
                           :summary,
                           :require_paths]


  @@default_value = {
    :authors                   => [],
    :autorequire               => nil,
    :bindir                    => 'bin',
    :cert_chain                => [],
    :date                      => TODAY,
    :dependencies              => [],
    :description               => nil,
    :email                     => nil,
    :executables               => [],
    :extensions                => [],
    :extra_rdoc_files          => [],
    :files                     => [],
    :homepage                  => nil,
    :licenses                  => [],
    :metadata                  => {},
    :name                      => nil,
    :platform                  => Gem::Platform::RUBY,
    :post_install_message      => nil,
    :rdoc_options              => [],
    :require_paths             => ['lib'],
    :required_ruby_version     => Gem::Requirement.default,
    :required_rubygems_version => Gem::Requirement.default,
    :requirements              => [],
    :rubyforge_project         => nil,
    :rubygems_version          => Gem::VERSION,
    :signing_key               => nil,
    :specification_version     => CURRENT_SPECIFICATION_VERSION,
    :summary                   => nil,
    :test_files                => [],
    :version                   => nil,
  }

  Dupable = { } # :nodoc:

  @@default_value.each do |k,v|
    case v
    when Time, Numeric, Symbol, true, false, nil
      Dupable[k] = false
    else
      Dupable[k] = true
    end
  end

  @@attributes = @@default_value.keys.sort_by { |s| s.to_s }
  @@array_attributes = @@default_value.reject { |k,v| v != [] }.keys
  @@nil_attributes, @@non_nil_attributes = @@default_value.keys.partition { |k|
    @@default_value[k].nil?
  }



  attr_accessor :name


  attr_reader :version


  def require_paths=(val)
    @require_paths = Array(val)
  end


  attr_accessor :rubygems_version


  attr_reader :summary


  def author= o
    self.authors = [o]
  end


  def authors= value
    @authors = Array(value).flatten.grep(String)
  end


  def platform= platform
    if @original_platform.nil? or
       @original_platform == Gem::Platform::RUBY then
      @original_platform = platform
    end

    case platform
    when Gem::Platform::CURRENT then
      @new_platform = Gem::Platform.local
      @original_platform = @new_platform.to_s

    when Gem::Platform then
      @new_platform = platform

    when nil, Gem::Platform::RUBY then
      @new_platform = Gem::Platform::RUBY
    when 'mswin32' then # was Gem::Platform::WIN32
      @new_platform = Gem::Platform.new 'x86-mswin32'
    when 'i586-linux' then # was Gem::Platform::LINUX_586
      @new_platform = Gem::Platform.new 'x86-linux'
    when 'powerpc-darwin' then # was Gem::Platform::DARWIN
      @new_platform = Gem::Platform.new 'ppc-darwin'
    else
      @new_platform = Gem::Platform.new platform
    end

    @platform = @new_platform.to_s

    invalidate_memoized_attributes

    @new_platform
  end


  def files
    @files = [@files,
              @test_files,
              add_bindir(@executables),
              @extra_rdoc_files,
              @extensions,
             ].flatten.uniq.compact.sort
  end



  attr_accessor :bindir


  attr_accessor :cert_chain


  attr_reader :description


  attr_accessor :email


  attr_accessor :homepage


  attr_accessor :post_install_message


  attr_reader :required_ruby_version


  attr_reader :required_rubygems_version


  attr_accessor :signing_key


  attr_accessor :metadata


  def add_development_dependency(gem, *requirements)
    add_dependency_with_type(gem, :development, *requirements)
  end


  def add_runtime_dependency(gem, *requirements)
    add_dependency_with_type(gem, :runtime, *requirements)
  end


  def executables
    @executables ||= []
  end


  def extensions
    @extensions ||= []
  end


  def extra_rdoc_files
    @extra_rdoc_files ||= []
  end


  def installed_by_version # :nodoc:
    @installed_by_version ||= Gem::Version.new(0)
  end


  def installed_by_version= version # :nodoc:
    @installed_by_version = Gem::Version.new version
  end


  def license=o
    self.licenses = [o]
  end


  def licenses= licenses
    @licenses = Array licenses
  end


  def rdoc_options
    @rdoc_options ||= []
  end


  def required_ruby_version= req
    @required_ruby_version = Gem::Requirement.create req
  end


  def required_rubygems_version= req
    @required_rubygems_version = Gem::Requirement.create req
  end


  def requirements
    @requirements ||= []
  end


  def test_files= files # :nodoc:
    @test_files = Array files
  end



  attr_accessor :activated

  alias :activated? :activated


  attr_accessor :autorequire # :nodoc:


  attr_writer :default_executable


  attr_writer :original_platform # :nodoc:


  attr_accessor :rubyforge_project


  attr_accessor :specification_version

  def self._all # :nodoc:
    unless defined?(@@all) && @@all then
      @@all = stubs.map(&:to_spec)

      specs = {}
      Gem.loaded_specs.each_value{|s| specs[s] = true}
      @@all.each{|s| s.activated = true if specs[s]}
    end
    @@all
  end

  def self._clear_load_cache # :nodoc:
    LOAD_CACHE.clear
  end

  def self.each_gemspec(dirs) # :nodoc:
    dirs.each do |dir|
      Dir[File.join(dir, "*.gemspec")].each do |path|
        yield path.untaint
      end
    end
  end

  def self.each_stub(dirs) # :nodoc:
    each_gemspec(dirs) do |path|
      stub = Gem::StubSpecification.new(path)
      yield stub if stub.valid?
    end
  end

  def self.each_spec(dirs) # :nodoc:
    each_gemspec(dirs) do |path|
      spec = self.load path
      yield spec if spec
    end
  end


  def self.stubs
    @@stubs ||= begin
      stubs = {}
      each_stub([default_specifications_dir] + dirs) do |stub|
        stubs[stub.full_name] ||= stub
      end

      stubs = stubs.values
      _resort!(stubs)
      stubs
    end
  end

  def self._resort!(specs) # :nodoc:
    specs.sort! { |a, b|
      names = a.name <=> b.name
      next names if names.nonzero?
      b.version <=> a.version
    }
  end


  def self.load_defaults
    each_spec([default_specifications_dir]) do |spec|
      Gem.register_default_spec(spec)
    end
  end


  def self.add_spec spec


    raise "nil spec!" unless spec # TODO: remove once we're happy with tests

    return if _all.include? spec

    _all << spec
    stubs << spec
    _resort!(_all)
    _resort!(stubs)
  end


  def self.add_specs *specs
    raise "nil spec!" if specs.any?(&:nil?) # TODO: remove once we're happy


    specs.each do |spec| # TODO: slow
      add_spec spec
    end
  end


  def self.all
    warn "NOTE: Specification.all called from #{caller.first}" unless
      Gem::Deprecate.skip
    _all
  end


  def self.all= specs
    @@all = @@stubs = specs
  end


  def self.all_names
    self._all.map(&:full_name)
  end


  def self.array_attributes
    @@array_attributes.dup
  end


  def self.attribute_names
    @@attributes.dup
  end


  def self.dirs
    @@dirs ||= Gem.path.collect { |dir|
      File.join dir.dup.untaint, "specifications"
    }
  end


  def self.dirs= dirs
    self.reset

    @@dirs = Array(dirs).map { |dir| File.join dir, "specifications" }
  end

  extend Enumerable


  def self.each
    return enum_for(:each) unless block_given?

    self._all.each do |x|
      yield x
    end
  end


  def self.find_all_by_name name, *requirements
    requirements = Gem::Requirement.default if requirements.empty?


    Gem::Dependency.new(name, *requirements).matching_specs
  end


  def self.find_by_name name, *requirements
    requirements = Gem::Requirement.default if requirements.empty?


    Gem::Dependency.new(name, *requirements).to_spec
  end


  def self.find_by_path path
    self.find { |spec|
      spec.contains_requirable_file? path
    }
  end


  def self.find_inactive_by_path path
    stub = stubs.find { |s|
      s.contains_requirable_file? path unless s.activated?
    }
    stub && stub.to_spec
  end


  def self.find_in_unresolved path
    specs = unresolved_deps.values.map { |dep| dep.to_specs }.flatten

    specs.find_all { |spec| spec.contains_requirable_file? path }
  end


  def self.find_in_unresolved_tree path
    specs = unresolved_deps.values.map { |dep| dep.to_specs }.flatten

    specs.reverse_each do |spec|
      trails = []
      spec.traverse do |from_spec, dep, to_spec, trail|
        next unless to_spec.conflicts.empty?
        trails << trail if to_spec.contains_requirable_file? path
      end

      next if trails.empty?

      return trails.map(&:reverse).sort.first.reverse
    end

    []
  end


  def self.from_yaml(input)
    Gem.load_yaml

    input = normalize_yaml_input input
    spec = YAML.load input

    if spec && spec.class == FalseClass then
      raise Gem::EndOfYAMLException
    end

    unless Gem::Specification === spec then
      raise Gem::Exception, "YAML data doesn't evaluate to gem specification"
    end

    spec.specification_version ||= NONEXISTENT_SPECIFICATION_VERSION
    spec.reset_nil_attributes_to_default

    spec
  end


  def self.latest_specs prerelease = false
    result = Hash.new { |h,k| h[k] = {} }
    native = {}

    Gem::Specification.reverse_each do |spec|
      next if spec.version.prerelease? unless prerelease

      native[spec.name] = spec.version if spec.platform == Gem::Platform::RUBY
      result[spec.name][spec.platform] = spec
    end

    result.map(&:last).map(&:values).flatten.reject { |spec|
      minimum = native[spec.name]
      minimum && spec.version < minimum
    }.sort_by{ |tup| tup.name }
  end


  def self.load file
    return unless file
    file = file.dup.untaint
    return unless File.file?(file)

    spec = LOAD_CACHE[file]
    return spec if spec

    code = if defined? Encoding
             File.read file, :mode => 'r:UTF-8:-'
           else
             File.read file
           end

    code.untaint

    begin
      #nodyna <eval-2251> <EV COMPLEX (change-prone variables)>
      spec = eval code, binding, file

      if Gem::Specification === spec
        spec.loaded_from = File.expand_path file.to_s
        LOAD_CACHE[file] = spec
        return spec
      end

      warn "[#{file}] isn't a Gem::Specification (#{spec.class} instead)."
    rescue SignalException, SystemExit
      raise
    rescue SyntaxError, Exception => e
      warn "Invalid gemspec in [#{file}]: #{e}"
    end

    nil
  end


  def self.non_nil_attributes
    @@non_nil_attributes.dup
  end


  def self.normalize_yaml_input(input)
    result = input.respond_to?(:read) ? input.read : input
    result = "--- " + result unless result =~ /\A--- /
    result.gsub!(/ !!null \n/, " \n")
    result.gsub!(/^(date: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+?)Z/, '\1 Z')
    result
  end


  def self.outdated
    outdated_and_latest_version.map { |local, _| local.name }
  end


  def self.outdated_and_latest_version
    return enum_for __method__ unless block_given?

    fetcher = Gem::SpecFetcher.fetcher

    latest_specs(true).each do |local_spec|
      dependency =
        Gem::Dependency.new local_spec.name, ">= #{local_spec.version}"

      remotes, = fetcher.search_for_dependency dependency
      remotes  = remotes.map { |n, _| n.version }

      latest_remote = remotes.sort.last

      yield [local_spec, latest_remote] if
        latest_remote and local_spec.version < latest_remote
    end

    nil
  end


  def self.remove_spec spec
    _all.delete spec
    stubs.delete_if { |s| s.full_name == spec.full_name }
  end


  def self.required_attribute?(name)
    @@required_attributes.include? name.to_sym
  end


  def self.required_attributes
    @@required_attributes.dup
  end


  def self.reset
    @@dirs = nil
    Gem.pre_reset_hooks.each { |hook| hook.call }
    @@all = nil
    @@stubs = nil
    _clear_load_cache
    unresolved = unresolved_deps
    unless unresolved.empty? then
      w = "W" + "ARN"
      warn "#{w}: Unresolved specs during Gem::Specification.reset:"
      unresolved.values.each do |dep|
        warn "      #{dep}"
      end
      warn "#{w}: Clearing out unresolved specs."
      warn "Please report a bug if this causes problems."
      unresolved.clear
    end
    Gem.post_reset_hooks.each { |hook| hook.call }
  end

  def self.unresolved_deps
    @unresolved_deps ||= Hash.new { |h, n| h[n] = Gem::Dependency.new n }
  end


  def self._load(str)
    array = Marshal.load str

    spec = Gem::Specification.new
    #nodyna <instance_variable_set-2252> <IVS MODERATE (private access)>
    spec.instance_variable_set :@specification_version, array[1]

    current_version = CURRENT_SPECIFICATION_VERSION

    field_count = if spec.specification_version > current_version then
                    #nodyna <instance_variable_set-2253> <IVS MODERATE (private access)>
                    spec.instance_variable_set :@specification_version,
                                               current_version
                    MARSHAL_FIELDS[current_version]
                  else
                    MARSHAL_FIELDS[spec.specification_version]
                  end

    if array.size < field_count then
      raise TypeError, "invalid Gem::Specification format #{array.inspect}"
    end


    array.map! { |e| e.kind_of?(YAML::PrivateType) ? nil : e }

    #nodyna <instance_variable_set-2254> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@rubygems_version,          array[0]
    #nodyna <instance_variable_set-2255> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@name,                      array[2]
    #nodyna <instance_variable_set-2256> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@version,                   array[3]
    spec.date =                                             array[4]
    #nodyna <instance_variable_set-2257> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@summary,                   array[5]
    #nodyna <instance_variable_set-2258> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@required_ruby_version,     array[6]
    #nodyna <instance_variable_set-2259> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@required_rubygems_version, array[7]
    #nodyna <instance_variable_set-2260> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@original_platform,         array[8]
    #nodyna <instance_variable_set-2261> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@dependencies,              array[9]
    #nodyna <instance_variable_set-2262> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@rubyforge_project,         array[10]
    #nodyna <instance_variable_set-2263> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@email,                     array[11]
    #nodyna <instance_variable_set-2264> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@authors,                   array[12]
    #nodyna <instance_variable_set-2265> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@description,               array[13]
    #nodyna <instance_variable_set-2266> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@homepage,                  array[14]
    #nodyna <instance_variable_set-2267> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@has_rdoc,                  array[15]
    #nodyna <instance_variable_set-2268> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@new_platform,              array[16]
    #nodyna <instance_variable_set-2269> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@platform,                  array[16].to_s
    #nodyna <instance_variable_set-2270> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@license,                   array[17]
    #nodyna <instance_variable_set-2271> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@metadata,                  array[18]
    #nodyna <instance_variable_set-2272> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@loaded,                    false
    #nodyna <instance_variable_set-2273> <IVS MODERATE (variable definition)>
    spec.instance_variable_set :@activated,                 false

    spec
  end

  def <=>(other) # :nodoc:
    sort_obj <=> other.sort_obj
  end

  def == other # :nodoc:
    self.class === other &&
      name == other.name &&
      version == other.version &&
      platform == other.platform
  end


  def _dump(limit)
    Marshal.dump [
      @rubygems_version,
      @specification_version,
      @name,
      @version,
      date,
      @summary,
      @required_ruby_version,
      @required_rubygems_version,
      @original_platform,
      @dependencies,
      @rubyforge_project,
      @email,
      @authors,
      @description,
      @homepage,
      true, # has_rdoc
      @new_platform,
      @licenses,
      @metadata
    ]
  end


  def activate
    other = Gem.loaded_specs[self.name]
    if other then
      check_version_conflict other
      return false
    end

    raise_if_conflicts

    activate_dependencies
    add_self_to_load_path

    Gem.loaded_specs[self.name] = self
    @activated = true
    @loaded = true

    return true
  end


  def activate_dependencies
    unresolved = Gem::Specification.unresolved_deps

    self.runtime_dependencies.each do |spec_dep|
      if loaded = Gem.loaded_specs[spec_dep.name]
        next if spec_dep.matches_spec? loaded

        msg = "can't satisfy '#{spec_dep}', already activated '#{loaded.full_name}'"
        e = Gem::LoadError.new msg
        e.name = spec_dep.name

        raise e
      end

      specs = spec_dep.to_specs

      if specs.size == 1 then
        specs.first.activate
      else
        name = spec_dep.name
        unresolved[name] = unresolved[name].merge spec_dep
      end
    end

    unresolved.delete self.name
  end


  def add_bindir(executables)
    return nil if executables.nil?

    if @bindir then
      Array(executables).map { |e| File.join(@bindir, e) }
    else
      executables
    end
  rescue
    return nil
  end


  def add_dependency_with_type(dependency, type, *requirements)
    requirements = if requirements.empty? then
                     Gem::Requirement.default
                   else
                     requirements.flatten
                   end

    unless dependency.respond_to?(:name) &&
           dependency.respond_to?(:version_requirements)
      dependency = Gem::Dependency.new(dependency.to_s, requirements, type)
    end

    dependencies << dependency
  end

  private :add_dependency_with_type

  alias add_dependency add_runtime_dependency


  def add_self_to_load_path
    return if default_gem?

    paths = full_require_paths

    insert_index = Gem.load_path_insert_index

    if insert_index then
      $LOAD_PATH.insert(insert_index, *paths)
    else
      $LOAD_PATH.unshift(*paths)
    end
  end


  def author
    val = authors and val.first
  end


  def authors
    @authors ||= []
  end


  def bin_dir
    @bin_dir ||= File.join gem_dir, bindir # TODO: this is unfortunate
  end


  def bin_file name
    File.join bin_dir, name
  end


  def build_args
    if File.exist? build_info_file
      build_info = File.readlines build_info_file
      build_info = build_info.map { |x| x.strip }
      build_info.delete ""
      build_info
    else
      []
    end
  end


  def build_extensions # :nodoc:
    return if default_gem?
    return if extensions.empty?
    return if installed_by_version < Gem::Version.new('2.2.0.preview.2')
    return if File.exist? gem_build_complete_path
    return if !File.writable?(base_dir)
    return if !File.exist?(File.join(base_dir, 'extensions'))

    begin
      unresolved_deps = Gem::Specification.unresolved_deps.dup
      Gem::Specification.unresolved_deps.clear

      require 'rubygems/config_file'
      require 'rubygems/ext'
      require 'rubygems/user_interaction'

      ui = Gem::SilentUI.new
      Gem::DefaultUserInteraction.use_ui ui do
        builder = Gem::Ext::Builder.new self
        builder.build_extensions
      end
    ensure
      ui.close if ui
      Gem::Specification.unresolved_deps.replace unresolved_deps
    end
  end


  def build_info_dir
    File.join base_dir, "build_info"
  end


  def build_info_file
    File.join build_info_dir, "#{full_name}.info"
  end


  def bundled_gem_in_old_ruby?
    !default_gem? &&
      RUBY_VERSION < "2.0.0" &&
      summary == "This #{name} is bundled with Ruby"
  end


  def cache_dir
    @cache_dir ||= File.join base_dir, "cache"
  end


  def cache_file
    @cache_file ||= File.join cache_dir, "#{full_name}.gem"
  end


  def conflicts
    conflicts = {}
    self.runtime_dependencies.each { |dep|
      spec = Gem.loaded_specs[dep.name]
      if spec and not spec.satisfies_requirement? dep
        (conflicts[spec] ||= []) << dep
      end
    }
    conflicts
  end


  def date
    @date ||= TODAY
  end

  DateLike = Object.new # :nodoc:
  def DateLike.===(obj) # :nodoc:
    defined?(::Date) and Date === obj
  end

  DateTimeFormat = # :nodoc:
    /\A
     (\d{4})-(\d{2})-(\d{2})
     (\s+ \d{2}:\d{2}:\d{2}\.\d+ \s* (Z | [-+]\d\d:\d\d) )?
     \Z/x


  def date= date
    @date = case date
            when String then
              if DateTimeFormat =~ date then
                Time.utc($1.to_i, $2.to_i, $3.to_i)

              elsif /\A(\d{4})-(\d{2})-(\d{2}) \d{2}:\d{2}:\d{2}\.\d+?Z\z/ =~ date then
                Time.utc($1.to_i, $2.to_i, $3.to_i)
              else
                raise(Gem::InvalidSpecificationException,
                      "invalid date format in specification: #{date.inspect}")
              end
            when Time, DateLike then
              Time.utc(date.year, date.month, date.day)
            else
              TODAY
            end
  end


  def default_executable # :nodoc:
    if defined?(@default_executable) and @default_executable
      result = @default_executable
    elsif @executables and @executables.size == 1
      result = Array(@executables).first
    else
      result = nil
    end
    result
  end


  def default_value name
    @@default_value[name]
  end


  def dependencies
    @dependencies ||= []
  end


  def dependent_gems
    out = []
    Gem::Specification.each do |spec|
      spec.dependencies.each do |dep|
        if self.satisfies_requirement?(dep) then
          sats = []
          find_all_satisfiers(dep) do |sat|
            sats << sat
          end
          out << [spec, dep, sats]
        end
      end
    end
    out
  end


  def dependent_specs
    runtime_dependencies.map { |dep| dep.to_specs }.flatten
  end


  def description= str
    @description = str.to_s
  end


  def development_dependencies
    dependencies.select { |d| d.type == :development }
  end


  def doc_dir type = nil
    @doc_dir ||= File.join base_dir, 'doc', full_name

    if type then
      File.join @doc_dir, type
    else
      @doc_dir
    end
  end

  def encode_with coder # :nodoc:
    mark_version

    coder.add 'name', @name
    coder.add 'version', @version
    platform = case @original_platform
               when nil, '' then
                 'ruby'
               when String then
                 @original_platform
               else
                 @original_platform.to_s
               end
    coder.add 'platform', platform

    attributes = @@attributes.map(&:to_s) - %w[name version platform]
    attributes.each do |name|
      #nodyna <instance_variable_get-2274> <IVG COMPLEX (array)>
      coder.add name, instance_variable_get("@#{name}")
    end
  end

  def eql? other # :nodoc:
    self.class === other && same_attributes?(other)
  end


  def executable
    val = executables and val.first
  end


  def executable=o
    self.executables = [o]
  end


  def executables= value
    @executables = Array(value)
  end


  def extensions= extensions
    @extensions = Array extensions
  end


  def extra_rdoc_files= files
    @extra_rdoc_files = Array files
  end


  def file_name
    "#{full_name}.gem"
  end


  def files= files
    @files = Array files
  end


  def find_all_satisfiers dep
    Gem::Specification.each do |spec|
      yield spec if spec.satisfies_requirement? dep
    end
  end

  private :find_all_satisfiers


  def for_cache
    spec = dup

    spec.files = nil
    spec.test_files = nil

    spec
  end

  def find_full_gem_path # :nodoc:
    super || File.expand_path(File.join(gems_dir, original_name))
  end
  private :find_full_gem_path

  def full_name
    @full_name ||= super
  end


  def gem_build_complete_path # :nodoc:
    File.join extension_dir, 'gem.build_complete'
  end


  def gem_dir # :nodoc:
    super
  end


  def has_rdoc # :nodoc:
    true
  end


  def has_rdoc= ignored # :nodoc:
    @has_rdoc = true
  end

  alias :has_rdoc? :has_rdoc # :nodoc:


  def has_unit_tests? # :nodoc:
    not test_files.empty?
  end

  alias has_test_suite? has_unit_tests?

  def hash # :nodoc:
    name.hash ^ version.hash
  end

  def init_with coder # :nodoc:
    @installed_by_version ||= nil
    yaml_initialize coder.tag, coder.map
  end


  def initialize name = nil, version = nil
    @loaded = false
    @activated = false
    self.loaded_from = nil
    @original_platform = nil
    @installed_by_version = nil

    @@nil_attributes.each do |key|
      #nodyna <instance_variable_set-2275> <IVS COMPLEX (array)>
      instance_variable_set "@#{key}", nil
    end

    @@non_nil_attributes.each do |key|
      default = default_value(key)
      value = Dupable[key] ? default.dup : default
      #nodyna <instance_variable_set-2276> <IVS COMPLEX (array)>
      instance_variable_set "@#{key}", value
    end

    @new_platform = Gem::Platform::RUBY

    self.name = name if name
    self.version = version if version

    yield self if block_given?
  end


  def initialize_copy other_spec
    self.class.array_attributes.each do |name|
      name = :"@#{name}"
      next unless other_spec.instance_variable_defined? name

      begin
        #nodyna <instance_variable_get-2277> <IVG COMPLEX (array)>
        val = other_spec.instance_variable_get(name)
        if val then
          #nodyna <instance_variable_set-2278> <IVS COMPLEX (array)>
          instance_variable_set name, val.dup
        elsif Gem.configuration.really_verbose
          warn "WARNING: #{full_name} has an invalid nil value for #{name}"
        end
      rescue TypeError
        e = Gem::FormatException.new \
          "#{full_name} has an invalid value for #{name}"

        e.file_path = loaded_from
        raise e
      end
    end
  end


  def invalidate_memoized_attributes
    @full_name = nil
    @cache_file = nil
  end

  private :invalidate_memoized_attributes

  def inspect # :nodoc:
    if $DEBUG
      super
    else
      "#<#{self.class}:0x#{__id__.to_s(16)} #{full_name}>"
    end
  end


  def lib_dirs_glob
    dirs = if self.require_paths.size > 1 then
             "{#{self.require_paths.join(',')}}"
           else
             self.require_paths.first
           end

    "#{self.full_gem_path}/#{dirs}"
  end


  def lib_files
    @files.select do |file|
      require_paths.any? do |path|
        file.start_with? path
      end
    end
  end


  def license
    val = licenses and val.first
  end


  def licenses
    @licenses ||= []
  end

  def loaded_from= path # :nodoc:
    super

    @bin_dir       = nil
    @cache_dir     = nil
    @cache_file    = nil
    @doc_dir       = nil
    @ri_dir        = nil
    @spec_dir      = nil
    @spec_file     = nil
  end


  def mark_version
    @rubygems_version = Gem::VERSION
  end


  def matches_for_glob glob # TODO: rename?
    glob = File.join(self.lib_dirs_glob, glob)

    Dir[glob].map { |f| f.untaint } # FIX our tests are broken, run w/ SAFE=1
  end


  def method_missing(sym, *a, &b) # :nodoc:
    if @specification_version > CURRENT_SPECIFICATION_VERSION and
      sym.to_s =~ /=$/ then
      warn "ignoring #{sym} loading #{full_name}" if $DEBUG
    else
      super
    end
  end


  def missing_extensions?
    return false if default_gem?
    return false if extensions.empty?
    return false if installed_by_version < Gem::Version.new('2.2.0.preview.2')
    return false if File.exist? gem_build_complete_path

    true
  end


  def normalize
    if defined?(@extra_rdoc_files) and @extra_rdoc_files then
      @extra_rdoc_files.uniq!
      @files ||= []
      @files.concat(@extra_rdoc_files)
    end

    @files            = @files.uniq if @files
    @extensions       = @extensions.uniq if @extensions
    @test_files       = @test_files.uniq if @test_files
    @executables      = @executables.uniq if @executables
    @extra_rdoc_files = @extra_rdoc_files.uniq if @extra_rdoc_files
  end


  def name_tuple
    Gem::NameTuple.new name, version, original_platform
  end


  def original_name # :nodoc:
    if platform == Gem::Platform::RUBY or platform.nil? then
      "#{@name}-#{@version}"
    else
      "#{@name}-#{@version}-#{@original_platform}"
    end
  end


  def original_platform # :nodoc:
    @original_platform ||= platform
  end


  def platform
    @new_platform ||= Gem::Platform::RUBY
  end

  def pretty_print(q) # :nodoc:
    q.group 2, 'Gem::Specification.new do |s|', 'end' do
      q.breakable

      attributes = @@attributes - [:name, :version]
      attributes.unshift :installed_by_version
      attributes.unshift :version
      attributes.unshift :name

      attributes.each do |attr_name|
        #nodyna <send-2279> <SD MODERATE (array)>
        current_value = self.send attr_name
        if current_value != default_value(attr_name) or
           self.class.required_attribute? attr_name then

          q.text "s.#{attr_name} = "

          if attr_name == :date then
            current_value = current_value.utc

            q.text "Time.utc(#{current_value.year}, #{current_value.month}, #{current_value.day})"
          else
            q.pp current_value
          end

          q.breakable
        end
      end
    end
  end


  def check_version_conflict other # :nodoc:
    return if self.version == other.version


    msg = "can't activate #{full_name}, already activated #{other.full_name}"

    e = Gem::LoadError.new msg
    e.name = self.name

    raise e
  end

  private :check_version_conflict


  def raise_if_conflicts # :nodoc:
    conf = self.conflicts

    unless conf.empty? then
      raise Gem::ConflictError.new self, conf
    end
  end


  def rdoc_options= options
    @rdoc_options = Array options
  end


  def require_path
    val = require_paths and val.first
  end


  def require_path= path
    self.require_paths = Array(path)
  end


  def requirements= req
    @requirements = Array req
  end

  def respond_to_missing? m, include_private = false # :nodoc:
    false
  end


  def ri_dir
    @ri_dir ||= File.join base_dir, 'ri', full_name
  end


  def ruby_code(obj)
    case obj
    when String            then obj.dump
    when Array             then '[' + obj.map { |x| ruby_code x }.join(", ") + ']'
    when Hash              then
      seg = obj.keys.sort.map { |k| "#{k.to_s.dump} => #{obj[k].to_s.dump}" }
      "{ #{seg.join(', ')} }"
    when Gem::Version      then obj.to_s.dump
    when DateLike          then obj.strftime('%Y-%m-%d').dump
    when Time              then obj.strftime('%Y-%m-%d').dump
    when Numeric           then obj.inspect
    when true, false, nil  then obj.inspect
    when Gem::Platform     then "Gem::Platform.new(#{obj.to_a.inspect})"
    when Gem::Requirement  then
      list = obj.as_list
      "Gem::Requirement.new(#{ruby_code(list.size == 1 ? obj.to_s : list)})"
    else raise Gem::Exception, "ruby_code case not handled: #{obj.class}"
    end
  end

  private :ruby_code


  def runtime_dependencies
    dependencies.select { |d| d.type == :runtime }
  end


  def same_attributes? spec
    #nodyna <send-2280> <SD MODERATE (change-prone variables)>
    #nodyna <send-2281> <SD MODERATE (change-prone variables)>
    @@attributes.all? { |name, default| self.send(name) == spec.send(name) }
  end

  private :same_attributes?


  def satisfies_requirement? dependency
    return @name == dependency.name &&
      dependency.requirement.satisfied_by?(@version)
  end


  def sort_obj
    [@name, @version, @new_platform == Gem::Platform::RUBY ? -1 : 1]
  end


  def source # :nodoc:
    Gem::Source::Installed.new
  end


  def spec_dir
    @spec_dir ||= File.join base_dir, "specifications"
  end


  def spec_file
    @spec_file ||= File.join spec_dir, "#{full_name}.gemspec"
  end


  def spec_name
    "#{full_name}.gemspec"
  end


  def summary= str
    @summary = str.to_s.strip.
      gsub(/(\w-)\n[ \t]*(\w)/, '\1\2').gsub(/\n[ \t]*/, " ") # so. weird.
  end


  def test_file # :nodoc:
    val = test_files and val.first
  end


  def test_file= file # :nodoc:
    self.test_files = [file]
  end


  def test_files # :nodoc:
    if defined? @test_suite_file then
      @test_files = [@test_suite_file].flatten
      @test_suite_file = nil
    end
    if defined?(@test_files) and @test_files then
      @test_files
    else
      @test_files = []
    end
  end


  def to_ruby
    mark_version
    result = []
    result << "# -*- encoding: utf-8 -*-"
    result << "#{Gem::StubSpecification::PREFIX}#{name} #{version} #{platform} #{raw_require_paths.join("\0")}"
    result << "#{Gem::StubSpecification::PREFIX}#{extensions.join "\0"}" unless
      extensions.empty?
    result << nil
    result << "Gem::Specification.new do |s|"

    result << "  s.name = #{ruby_code name}"
    result << "  s.version = #{ruby_code version}"
    unless platform.nil? or platform == Gem::Platform::RUBY then
      result << "  s.platform = #{ruby_code original_platform}"
    end
    result << ""
    result << "  s.required_rubygems_version = #{ruby_code required_rubygems_version} if s.respond_to? :required_rubygems_version="

    if metadata and !metadata.empty?
      result << "  s.metadata = #{ruby_code metadata} if s.respond_to? :metadata="
    end
    result << "  s.require_paths = #{ruby_code raw_require_paths}"

    handled = [
      :dependencies,
      :name,
      :platform,
      :require_paths,
      :required_rubygems_version,
      :specification_version,
      :version,
      :has_rdoc,
      :default_executable,
      :metadata
    ]

    @@attributes.each do |attr_name|
      next if handled.include? attr_name
      #nodyna <send-2282> <SD MODERATE (change-prone variables)>
      current_value = self.send(attr_name)
      if current_value != default_value(attr_name) or
         self.class.required_attribute? attr_name then
        result << "  s.#{attr_name} = #{ruby_code current_value}"
      end
    end

    if @installed_by_version then
      result << nil
      result << "  s.installed_by_version = \"#{Gem::VERSION}\" if s.respond_to? :installed_by_version"
    end

    unless dependencies.empty? then
      result << nil
      result << "  if s.respond_to? :specification_version then"
      result << "    s.specification_version = #{specification_version}"
      result << nil

      result << "    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then"

      dependencies.each do |dep|
        req = dep.requirements_list.inspect
        #nodyna <instance_variable_set-2283> <IVS MODERATE (private access)>
        dep.instance_variable_set :@type, :runtime if dep.type.nil? # HACK
        result << "      s.add_#{dep.type}_dependency(%q<#{dep.name}>, #{req})"
      end

      result << "    else"

      dependencies.each do |dep|
        version_reqs_param = dep.requirements_list.inspect
        result << "      s.add_dependency(%q<#{dep.name}>, #{version_reqs_param})"
      end

      result << '    end'

      result << "  else"
      dependencies.each do |dep|
        version_reqs_param = dep.requirements_list.inspect
        result << "    s.add_dependency(%q<#{dep.name}>, #{version_reqs_param})"
      end
      result << "  end"
    end

    result << "end"
    result << nil

    result.join "\n"
  end


  def to_ruby_for_cache
    for_cache.to_ruby
  end

  def to_s # :nodoc:
    "#<Gem::Specification name=#{@name} version=#{@version}>"
  end


  def to_spec
    self
  end

  def to_yaml(opts = {}) # :nodoc:
    if (YAML.const_defined?(:ENGINE) && !YAML::ENGINE.syck?) ||
        (defined?(Psych) && YAML == Psych) then
      unless Gem.const_defined?(:NoAliasYAMLTree)
        require 'rubygems/psych_tree'
      end

      builder = Gem::NoAliasYAMLTree.create
      builder << self
      ast = builder.tree

      io = Gem::StringSink.new
      io.set_encoding Encoding::UTF_8 if Object.const_defined? :Encoding

      Psych::Visitors::Emitter.new(io).accept(ast)

      io.string.gsub(/ !!null \n/, " \n")
    else
      YAML.quick_emit object_id, opts do |out|
        out.map taguri, to_yaml_style do |map|
          encode_with map
        end
      end
    end
  end


  def traverse trail = [], &block
    trail = trail + [self]
    runtime_dependencies.each do |dep|
      dep.to_specs.each do |dep_spec|
        block[self, dep, dep_spec, trail + [dep_spec]]
        dep_spec.traverse(trail, &block) unless
          trail.map(&:name).include? dep_spec.name
      end
    end
  end


  def validate packaging = true
    @warnings = 0
    require 'rubygems/user_interaction'
    extend Gem::UserInteraction
    normalize

    nil_attributes = self.class.non_nil_attributes.find_all do |attrname|
      #nodyna <instance_variable_get-2284> <IVG COMPLEX (array)>
      instance_variable_get("@#{attrname}").nil?
    end

    unless nil_attributes.empty? then
      raise Gem::InvalidSpecificationException,
        "#{nil_attributes.join ', '} must not be nil"
    end

    if packaging and rubygems_version != Gem::VERSION then
      raise Gem::InvalidSpecificationException,
            "expected RubyGems version #{Gem::VERSION}, was #{rubygems_version}"
    end

    @@required_attributes.each do |symbol|
      #nodyna <send-2285> <SD MODERATE (array)>
      unless self.send symbol then
        raise Gem::InvalidSpecificationException,
              "missing value for attribute #{symbol}"
      end
    end

    unless String === name then
      raise Gem::InvalidSpecificationException,
            "invalid value for attribute name: \"#{name.inspect}\""
    end

    if raw_require_paths.empty? then
      raise Gem::InvalidSpecificationException,
            'specification must have at least one require_path'
    end

    @files.delete_if            { |x| File.directory?(x) }
    @test_files.delete_if       { |x| File.directory?(x) }
    @executables.delete_if      { |x| File.directory?(File.join(@bindir, x)) }
    @extra_rdoc_files.delete_if { |x| File.directory?(x) }
    @extensions.delete_if       { |x| File.directory?(x) }

    non_files = files.reject { |x| File.file?(x) }

    unless not packaging or non_files.empty? then
      raise Gem::InvalidSpecificationException,
            "[\"#{non_files.join "\", \""}\"] are not files"
    end

    if files.include? file_name then
      raise Gem::InvalidSpecificationException,
            "#{full_name} contains itself (#{file_name}), check your files list"
    end

    unless specification_version.is_a?(Fixnum)
      raise Gem::InvalidSpecificationException,
            'specification_version must be a Fixnum (did you mean version?)'
    end

    case platform
    when Gem::Platform, Gem::Platform::RUBY then # ok
    else
      raise Gem::InvalidSpecificationException,
            "invalid platform #{platform.inspect}, see Gem::Platform"
    end

    self.class.array_attributes.each do |field|
      #nodyna <send-2286> <SD MODERATE (array)>
      val = self.send field
      klass = case field
              when :dependencies
                Gem::Dependency
              else
                String
              end

      unless Array === val and val.all? { |x| x.kind_of?(klass) } then
        raise(Gem::InvalidSpecificationException,
              "#{field} must be an Array of #{klass}")
      end
    end

    [:authors].each do |field|
      #nodyna <send-2287> <SD TRIVIAL (array)>
      val = self.send field
      raise Gem::InvalidSpecificationException, "#{field} may not be empty" if
        val.empty?
    end

    unless Hash === metadata
      raise Gem::InvalidSpecificationException,
              'metadata must be a hash'
    end

    metadata.keys.each do |k|
      if !k.kind_of?(String)
        raise Gem::InvalidSpecificationException,
                'metadata keys must be a String'
      end

      if k.size > 128
        raise Gem::InvalidSpecificationException,
                "metadata key too large (#{k.size} > 128)"
      end
    end

    metadata.values.each do |k|
      if !k.kind_of?(String)
        raise Gem::InvalidSpecificationException,
                'metadata values must be a String'
      end

      if k.size > 1024
        raise Gem::InvalidSpecificationException,
                "metadata value too large (#{k.size} > 1024)"
      end
    end

    licenses.each { |license|
      if license.length > 64
        raise Gem::InvalidSpecificationException,
          "each license must be 64 characters or less"
      end
    }

    warning <<-warning if licenses.empty?
licenses is empty, but is recommended.  Use a license abbreviation from:
http://opensource.org/licenses/alphabetical
    warning

    validate_permissions


    lazy = '"FIxxxXME" or "TOxxxDO"'.gsub(/xxx/, '')

    unless authors.grep(/FI XME|TO DO/x).empty? then
      raise Gem::InvalidSpecificationException, "#{lazy} is not an author"
    end

    unless Array(email).grep(/FI XME|TO DO/x).empty? then
      raise Gem::InvalidSpecificationException, "#{lazy} is not an email"
    end

    if description =~ /FI XME|TO DO/x then
      raise Gem::InvalidSpecificationException, "#{lazy} is not a description"
    end

    if summary =~ /FI XME|TO DO/x then
      raise Gem::InvalidSpecificationException, "#{lazy} is not a summary"
    end

    if homepage and not homepage.empty? and
       homepage !~ /\A[a-z][a-z\d+.-]*:/i then
      raise Gem::InvalidSpecificationException,
            "\"#{homepage}\" is not a URI"
    end


    %w[author description email homepage summary].each do |attribute|
      #nodyna <send-2288> <SD MODERATE (array)>
      value = self.send attribute
      warning "no #{attribute} specified" if value.nil? or value.empty?
    end

    if description == summary then
      warning 'description and summary are identical'
    end

    warning "deprecated autorequire specified" if autorequire

    executables.each do |executable|
      executable_path = File.join(bindir, executable)
      shebang = File.read(executable_path, 2) == '#!'

      warning "#{executable_path} is missing #! line" unless shebang
    end

    validate_dependencies

    true
  ensure
    if $! or @warnings > 0 then
      alert_warning "See http://guides.rubygems.org/specification-reference/ for help"
    end
  end


  def validate_dependencies # :nodoc:
    seen = {}

    dependencies.each do |dep|
      if prev = seen[dep.name] then
        raise Gem::InvalidSpecificationException, <<-MESSAGE
duplicate dependency on #{dep}, (#{prev.requirement}) use:
    add_runtime_dependency '#{dep.name}', '#{dep.requirement}', '#{prev.requirement}'
        MESSAGE
      end

      seen[dep.name] = dep

      prerelease_dep = dep.requirements_list.any? do |req|
        Gem::Requirement.new(req).prerelease?
      end

      warning "prerelease dependency on #{dep} is not recommended" if
        prerelease_dep

      overly_strict = dep.requirement.requirements.length == 1 &&
        dep.requirement.requirements.any? do |op, version|
          op == '~>' and
            not version.prerelease? and
            version.segments.length > 2 and
            version.segments.first != 0
        end

      if overly_strict then
        _, dep_version = dep.requirement.requirements.first

        base = dep_version.segments.first 2

        warning <<-WARNING
pessimistic dependency on #{dep} may be overly strict
  if #{dep.name} is semantically versioned, use:
    add_#{dep.type}_dependency '#{dep.name}', '~> #{base.join '.'}', '>= #{dep_version}'
        WARNING
      end

      open_ended = dep.requirement.requirements.all? do |op, version|
        not version.prerelease? and (op == '>' or op == '>=')
      end

      if open_ended then
        op, dep_version = dep.requirement.requirements.first

        base = dep_version.segments.first 2

        bugfix = if op == '>' then
                   ", '> #{dep_version}'"
                 elsif op == '>=' and base != dep_version.segments then
                   ", '>= #{dep_version}'"
                 end

        warning <<-WARNING
open-ended dependency on #{dep} is not recommended
  if #{dep.name} is semantically versioned, use:
    add_#{dep.type}_dependency '#{dep.name}', '~> #{base.join '.'}'#{bugfix}
        WARNING
      end
    end
  end


  def validate_permissions
    return if Gem.win_platform?

    files.each do |file|
      next if File.stat(file).mode & 0444 == 0444
      warning "#{file} is not world-readable"
    end

    executables.each do |name|
      exec = File.join @bindir, name
      next if File.stat(exec).executable?
      warning "#{exec} is not executable"
    end
  end


  def version= version
    @version = Gem::Version.create(version)
    self.required_rubygems_version = '> 1.3.1' if @version.prerelease?
    invalidate_memoized_attributes

    return @version
  end

  def stubbed?
    false
  end

  def yaml_initialize(tag, vals) # :nodoc:
    vals.each do |ivar, val|
      case ivar
      when "date"
        self.date = val.untaint
      else
        #nodyna <instance_variable_set-2289> <IVS COMPLEX (array)>
        instance_variable_set "@#{ivar}", val.untaint
      end
    end

    @original_platform = @platform # for backwards compatibility
    self.platform = Gem::Platform.new @platform
  end


  def reset_nil_attributes_to_default
    nil_attributes = self.class.non_nil_attributes.find_all do |name|
      #nodyna <instance_variable_get-2290> <IVG COMPLEX (array)>
      !instance_variable_defined?("@#{name}") || instance_variable_get("@#{name}").nil?
    end

    nil_attributes.each do |attribute|
      default = self.default_value attribute

      value = case default
              when Time, Numeric, Symbol, true, false, nil then default
              else default.dup
              end

      #nodyna <instance_variable_set-2291> <IVS COMPLEX (array)>
      instance_variable_set "@#{attribute}", value
    end

    @installed_by_version ||= nil
  end

  def warning statement # :nodoc:
    @warnings += 1

    alert_warning statement
  end

  extend Gem::Deprecate

end

Gem.clear_paths
