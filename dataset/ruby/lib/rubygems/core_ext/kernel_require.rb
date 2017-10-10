
require 'monitor'

module Kernel

  RUBYGEMS_ACTIVATION_MONITOR = Monitor.new # :nodoc:

  if defined?(gem_original_require) then
    remove_method :require
  else

    alias gem_original_require require
    private :gem_original_require
  end


  def require path
    RUBYGEMS_ACTIVATION_MONITOR.enter

    path = path.to_path if path.respond_to? :to_path

    spec = Gem.find_unresolved_default_spec(path)
    if spec
      Gem.remove_unresolved_default_spec(spec)
      gem(spec.name)
    end


    if Gem::Specification.unresolved_deps.empty? then
      RUBYGEMS_ACTIVATION_MONITOR.exit
      return gem_original_require(path)
    end


    spec = Gem::Specification.stubs.find { |s|
      s.activated? and s.contains_requirable_file? path
    }

    begin
      RUBYGEMS_ACTIVATION_MONITOR.exit
      return gem_original_require(spec.to_fullpath(path) || path)
    end if spec


    found_specs = Gem::Specification.find_in_unresolved path

    if found_specs.empty? then
      found_specs = Gem::Specification.find_in_unresolved_tree path

      found_specs.each do |found_spec|
        found_spec.activate
      end

    else

      names = found_specs.map(&:name).uniq

      if names.size > 1 then
        RUBYGEMS_ACTIVATION_MONITOR.exit
        raise Gem::LoadError, "#{path} found in multiple gems: #{names.join ', '}"
      end

      valid = found_specs.select { |s| s.conflicts.empty? }.last

      unless valid then
        le = Gem::LoadError.new "unable to find a version of '#{names.first}' to activate"
        le.name = names.first
        RUBYGEMS_ACTIVATION_MONITOR.exit
        raise le
      end

      valid.activate
    end

    RUBYGEMS_ACTIVATION_MONITOR.exit
    return gem_original_require(path)
  rescue LoadError => load_error
    RUBYGEMS_ACTIVATION_MONITOR.enter

    if load_error.message.start_with?("Could not find") or
        (load_error.message.end_with?(path) and Gem.try_activate(path)) then
      RUBYGEMS_ACTIVATION_MONITOR.exit
      return gem_original_require(path)
    else
      RUBYGEMS_ACTIVATION_MONITOR.exit
    end

    raise load_error
  end

  private :require

end

