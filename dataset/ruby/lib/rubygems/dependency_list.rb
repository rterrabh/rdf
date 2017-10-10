
require 'tsort'
require 'rubygems/deprecate'


class Gem::DependencyList
  attr_reader :specs

  include Enumerable
  include TSort


  attr_accessor :development


  def self.from_specs
    list = new
    list.add(*Gem::Specification.to_a)
    list
  end


  def initialize development = false
    @specs = []

    @development = development
  end


  def add(*gemspecs)
    @specs.concat gemspecs
  end

  def clear
    @specs.clear
  end


  def dependency_order
    sorted = strongly_connected_components.flatten

    result = []
    seen = {}

    sorted.each do |spec|
      if index = seen[spec.name] then
        if result[index].version < spec.version then
          result[index] = spec
        end
      else
        seen[spec.name] = result.length
        result << spec
      end
    end

    result.reverse
  end


  def each(&block)
    dependency_order.each(&block)
  end

  def find_name(full_name)
    @specs.find { |spec| spec.full_name == full_name }
  end

  def inspect # :nodoc:
    "#<%s:0x%x %p>" % [self.class, object_id, map { |s| s.full_name }]
  end


  def ok?
    why_not_ok?(:quick).empty?
  end

  def why_not_ok? quick = false
    unsatisfied = Hash.new { |h,k| h[k] = [] }
    each do |spec|
      spec.runtime_dependencies.each do |dep|
        inst = Gem::Specification.any? { |installed_spec|
          dep.name == installed_spec.name and
            dep.requirement.satisfied_by? installed_spec.version
        }

        unless inst or @specs.find { |s| s.satisfies_requirement? dep } then
          unsatisfied[spec.name] << dep
          return unsatisfied if quick
        end
      end
    end

    unsatisfied
  end


  def ok_to_remove?(full_name, check_dev=true)
    gem_to_remove = find_name full_name

    siblings = @specs.find_all { |s|
      s.name == gem_to_remove.name &&
        s.full_name != gem_to_remove.full_name
    }

    deps = []

    @specs.each do |spec|
      check = check_dev ? spec.dependencies : spec.runtime_dependencies

      check.each do |dep|
        deps << dep if gem_to_remove.satisfies_requirement?(dep)
      end
    end

    deps.all? { |dep|
      siblings.any? { |s|
        s.satisfies_requirement? dep
      }
    }
  end


  def remove_specs_unsatisfied_by dependencies
    specs.reject! { |spec|
      dep = dependencies[spec.name]
      dep and not dep.requirement.satisfied_by? spec.version
    }
  end


  def remove_by_name(full_name)
    @specs.delete_if { |spec| spec.full_name == full_name }
  end


  def spec_predecessors
    result = Hash.new { |h,k| h[k] = [] }

    specs = @specs.sort.reverse

    specs.each do |spec|
      specs.each do |other|
        next if spec == other

        other.dependencies.each do |dep|
          if spec.satisfies_requirement? dep then
            result[spec] << other
          end
        end
      end
    end

    result
  end

  def tsort_each_node(&block)
    @specs.each(&block)
  end

  def tsort_each_child(node)
    specs = @specs.sort.reverse

    dependencies = node.runtime_dependencies
    dependencies.push(*node.development_dependencies) if @development

    dependencies.each do |dep|
      specs.each do |spec|
        if spec.satisfies_requirement? dep then
          yield spec
          break
        end
      end
    end
  end

  private


  def active_count(specs, ignored)
    specs.count { |spec| ignored[spec.full_name].nil? }
  end

end

