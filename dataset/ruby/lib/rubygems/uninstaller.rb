
require 'fileutils'
require 'rubygems'
require 'rubygems/dependency_list'
require 'rubygems/rdoc'
require 'rubygems/user_interaction'


class Gem::Uninstaller

  include Gem::UserInteraction


  attr_reader :bin_dir


  attr_reader :gem_home


  attr_reader :spec


  def initialize(gem, options = {})
    @gem                = gem
    @version            = options[:version] || Gem::Requirement.default
    @gem_home           = File.expand_path(options[:install_dir] || Gem.dir)
    @force_executables  = options[:executables]
    @force_all          = options[:all]
    @force_ignore       = options[:ignore]
    @bin_dir            = options[:bin_dir]
    @format_executable  = options[:format_executable]
    @abort_on_dependent = options[:abort_on_dependent]

    @check_dev         = options[:check_dev]

    if options[:force]
      @force_all = true
      @force_ignore = true
    end

    @user_install = false
    @user_install = options[:user_install] unless options[:install_dir]
  end


  def uninstall
    dependency = Gem::Dependency.new @gem, @version

    list = []

    dirs =
      Gem::Specification.dirs +
      [Gem::Specification.default_specifications_dir]

    Gem::Specification.each_spec dirs do |spec|
      next unless dependency.matches_spec? spec

      list << spec
    end

    default_specs, list = list.partition do |spec|
      spec.default_gem?
    end

    list, other_repo_specs = list.partition do |spec|
      @gem_home == spec.base_dir or
        (@user_install and spec.base_dir == Gem.user_dir)
    end

    list.sort!

    if list.empty? then
      if other_repo_specs.empty?
        if default_specs.empty?
          raise Gem::InstallError, "gem #{@gem.inspect} is not installed"
        else
          message =
            "gem #{@gem.inspect} cannot be uninstalled " +
            "because it is a default gem"
          raise Gem::InstallError, message
        end
      end

      other_repos = other_repo_specs.map { |spec| spec.base_dir }.uniq

      message = ["#{@gem} is not installed in GEM_HOME, try:"]
      message.concat other_repos.map { |repo|
        "\tgem uninstall -i #{repo} #{@gem}"
      }

      raise Gem::InstallError, message.join("\n")
    elsif @force_all then
      remove_all list

    elsif list.size > 1 then
      gem_names = list.map { |gem| gem.full_name }
      gem_names << "All versions"

      say
      _, index = choose_from_list "Select gem to uninstall:", gem_names

      if index == list.size then
        remove_all list
      elsif index >= 0 && index < list.size then
        uninstall_gem list[index]
      else
        say "Error: must enter a number [1-#{list.size+1}]"
      end
    else
      uninstall_gem list.first
    end
  end


  def uninstall_gem(spec)
    @spec = spec

    unless dependencies_ok? spec
      if abort_on_dependent? || !ask_if_ok(spec)
        raise Gem::DependencyRemovalException,
          "Uninstallation aborted due to dependent gem(s)"
      end
    end

    Gem.pre_uninstall_hooks.each do |hook|
      hook.call self
    end

    remove_executables @spec
    remove @spec

    Gem.post_uninstall_hooks.each do |hook|
      hook.call self
    end

    @spec = nil
  end


  def remove_executables(spec)
    return if spec.nil? or spec.executables.empty?

    executables = spec.executables.clone


    list = Gem::Specification.find_all { |s|
      s.name == spec.name && s.version != spec.version
    }

    list.each do |s|
      s.executables.each do |exe_name|
        executables.delete exe_name
      end
    end

    return if executables.empty?

    executables = executables.map { |exec| formatted_program_filename exec }

    remove = if @force_executables.nil? then
               ask_yes_no("Remove executables:\n" +
                          "\t#{executables.join ', '}\n\n" +
                          "in addition to the gem?",
                          true)
             else
               @force_executables
             end

    if remove then
      bin_dir = @bin_dir || Gem.bindir(spec.base_dir)

      raise Gem::FilePermissionError, bin_dir unless File.writable? bin_dir

      executables.each do |exe_name|
        say "Removing #{exe_name}"

        exe_file = File.join bin_dir, exe_name

        FileUtils.rm_f exe_file
        FileUtils.rm_f "#{exe_file}.bat"
      end
    else
      say "Executables and scripts will remain installed."
    end
  end


  def remove_all(list)
    list.each { |spec| uninstall_gem spec }
  end


  def remove(spec)
    unless path_ok?(@gem_home, spec) or
           (@user_install and path_ok?(Gem.user_dir, spec)) then
      e = Gem::GemNotInHomeException.new \
            "Gem '#{spec.full_name}' is not installed in directory #{@gem_home}"
      e.spec = spec

      raise e
    end

    raise Gem::FilePermissionError, spec.base_dir unless
      File.writable?(spec.base_dir)

    FileUtils.rm_rf spec.full_gem_path
    FileUtils.rm_rf spec.extension_dir

    old_platform_name = spec.original_name
    gemspec           = spec.spec_file

    unless File.exist? gemspec then
      gemspec = File.join(File.dirname(gemspec), "#{old_platform_name}.gemspec")
    end

    FileUtils.rm_rf gemspec

    gem = spec.cache_file
    gem = File.join(spec.cache_dir, "#{old_platform_name}.gem") unless
      File.exist? gem

    FileUtils.rm_rf gem

    Gem::RDoc.new(spec).remove

    say "Successfully uninstalled #{spec.full_name}"

    Gem::Specification.remove_spec spec
  end


  def path_ok?(gem_dir, spec)
    full_path     = File.join gem_dir, 'gems', spec.full_name
    original_path = File.join gem_dir, 'gems', spec.original_name

    full_path == spec.full_gem_path || original_path == spec.full_gem_path
  end


  def dependencies_ok? spec # :nodoc:
    return true if @force_ignore

    deplist = Gem::DependencyList.from_specs
    deplist.ok_to_remove?(spec.full_name, @check_dev)
  end


  def abort_on_dependent? # :nodoc:
    @abort_on_dependent
  end


  def ask_if_ok spec # :nodoc:
    msg = ['']
    msg << 'You have requested to uninstall the gem:'
    msg << "\t#{spec.full_name}"
    msg << ''

    siblings = Gem::Specification.select do |s|
                 s.name == spec.name && s.full_name != spec.full_name
               end

    spec.dependent_gems.each do |dep_spec, dep, satlist|
      unless siblings.any? { |s| s.satisfies_requirement? dep }
        msg << "#{dep_spec.name}-#{dep_spec.version} depends on #{dep}"
      end
    end

    msg << 'If you remove this gem, these dependencies will not be met.'
    msg << 'Continue with Uninstall?'
    return ask_yes_no(msg.join("\n"), false)
  end


  def formatted_program_filename filename # :nodoc:
    if @format_executable then
      require 'rubygems/installer'
      Gem::Installer.exec_format % File.basename(filename)
    else
      filename
    end
  end
end
