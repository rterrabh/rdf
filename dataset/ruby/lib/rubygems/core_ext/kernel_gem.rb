
module Kernel

  remove_method :gem if 'method' == defined? gem # from gem_prelude.rb on 1.9


  def gem(gem_name, *requirements) # :doc:
    skip_list = (ENV['GEM_SKIP'] || "").split(/:/)
    raise Gem::LoadError, "skipping #{gem_name}" if skip_list.include? gem_name

    if gem_name.kind_of? Gem::Dependency
      unless Gem::Deprecate.skip
        warn "#{Gem.location_of_caller.join ':'}:Warning: Kernel.gem no longer "\
          "accepts a Gem::Dependency object, please pass the name "\
          "and requirements directly"
      end

      requirements = gem_name.requirement
      gem_name = gem_name.name
    end

    dep = Gem::Dependency.new(gem_name, *requirements)

    loaded = Gem.loaded_specs[gem_name]

    return false if loaded && dep.matches_spec?(loaded)

    spec = dep.to_spec

    Gem::LOADED_SPECS_MUTEX.synchronize {
      spec.activate
    } if spec
  end

  private :gem

end
