require 'molinillo'
require 'cocoapods/resolver/lazy_specification'

module Pod
  class Resolver
    attr_reader :sandbox

    attr_reader :podfile

    attr_reader :locked_dependencies

    attr_accessor :sources

    def initialize(sandbox, podfile, locked_dependencies, sources)
      @sandbox = sandbox
      @podfile = podfile
      @locked_dependencies = locked_dependencies
      @sources = Array(sources)
      @platforms_by_dependency = Hash.new { |h, k| h[k] = [] }
      @cached_sets = {}
    end


    public


    def resolve
      dependencies = podfile.target_definition_list.flat_map do |target|
        target.dependencies.each do |dep|
          @platforms_by_dependency[dep].push(target.platform).uniq!
        end
      end
      @activated = Molinillo::Resolver.new(self, self).resolve(dependencies, locked_dependencies)
      specs_by_target.tap do |specs_by_target|
        specs_by_target.values.flatten.each do |spec|
          sandbox.store_head_pod(spec.name) if spec.version.head?
        end
      end
    rescue Molinillo::ResolverError => e
      handle_resolver_error(e)
    end

    def specs_by_target
      @specs_by_target ||= {}.tap do |specs_by_target|
        podfile.target_definition_list.each do |target|
          specs = target.dependencies.map(&:name).flat_map do |name|
            node = @activated.vertex_named(name)
            valid_dependencies_for_target_from_node(target, node) << node
          end

          specs_by_target[target] = specs.
            map(&:payload).
            uniq.
            sort_by(&:name)
        end
      end
    end


    public


    include Molinillo::SpecificationProvider

    def search_for(dependency)
      @search ||= {}
      @search[dependency] ||= begin
        requirement = Requirement.new(dependency.requirement.as_list << requirement_for_locked_pod_named(dependency.name))
        find_cached_set(dependency).
          all_specifications.
          select { |s| requirement.satisfied_by? s.version }.
          map { |s| s.subspec_by_name(dependency.name, false) }.
          compact.
          reverse
      end
      @search[dependency].dup
    end

    def dependencies_for(specification)
      specification.all_dependencies.map do |dependency|
        if dependency.root_name == Specification.root_name(specification.name)
          dependency.dup.tap { |d| d.specific_version = specification.version }
        else
          dependency
        end
      end
    end

    def name_for(dependency)
      dependency.name
    end

    def name_for_explicit_dependency_source
      'Podfile'
    end

    def name_for_locking_dependency_source
      'Podfile.lock'
    end

    def requirement_satisfied_by?(requirement, activated, spec)
      existing_vertices = activated.vertices.values.select do |v|
        Specification.root_name(v.name) ==  requirement.root_name
      end
      existing = existing_vertices.map(&:payload).compact.first
      requirement_satisfied =
        if existing
          existing.version == spec.version && requirement.requirement.satisfied_by?(spec.version)
        else
          requirement.requirement.satisfied_by? spec.version
        end
      requirement_satisfied && !(
        spec.version.prerelease? &&
        existing_vertices.flat_map(&:requirements).none? { |r| r.prerelease? || r.external_source || r.head? }
      ) && spec_is_platform_compatible?(activated, requirement, spec)
    end

    def sort_dependencies(dependencies, activated, conflicts)
      dependencies.sort_by do |dependency|
        name = name_for(dependency)
        [
          activated.vertex_named(name).payload ? 0 : 1,
          dependency.prerelease? ? 0 : 1,
          conflicts[name] ? 0 : 1,
          search_for(dependency).count,
        ]
      end
    end


    public


    include Molinillo::UI

    def output
      UI
    end

    def before_resolution
    end

    def after_resolution
    end

    def indicate_progress
    end


    private


    attr_accessor :cached_sets


    private


    def find_cached_set(dependency)
      name = dependency.root_name
      unless cached_sets[name]
        if dependency.external_source
          spec = sandbox.specification(name)
          unless spec
            raise StandardError, '[Bug] Unable to find the specification ' \
              "for `#{dependency}`."
          end
          set = Specification::Set::External.new(spec)
        else
          set = create_set_from_sources(dependency)
        end
        if set && dependency.head?
          set = Specification::Set::Head.new(set.specification)
        end
        cached_sets[name] = set
        unless set
          raise Molinillo::NoSuchDependencyError.new(dependency) # rubocop:disable Style/RaiseArgs
        end
      end
      cached_sets[name]
    end

    def requirement_for_locked_pod_named(name)
      if vertex = locked_dependencies.vertex_named(name)
        if dependency = vertex.payload
          dependency.requirement
        end
      end
    end

    def create_set_from_sources(dependency)
      aggregate.search(dependency)
    end

    def aggregate
      @aggregate ||= Source::Aggregate.new(sources.map(&:repo))
    end

    def validate_platform(spec, target)
      unless spec.available_platforms.any? { |p| target.platform.to_sym == p.to_sym }
        raise Informative, "The platform of the target `#{target.name}` "     \
          "(#{target.platform}) is not compatible with `#{spec}`, which does "  \
          "not support `#{target.platform.name}`."
      end
    end

    def handle_resolver_error(error)
      message = error.message
      case error
      when Molinillo::VersionConflict
        error.conflicts.each do |name, conflict|
          lockfile_reqs = conflict.requirements[name_for_locking_dependency_source]
          if lockfile_reqs && lockfile_reqs.last && lockfile_reqs.last.prerelease? && !conflict.existing
            message = 'Due to the previous naïve CocoaPods resolver, ' \
              "you were using a pre-release version of `#{name}`, " \
              'without explicitly asking for a pre-release version, which now leads to a conflict. ' \
              'Please decide to either use that pre-release version by adding the ' \
              'version requirement to your Podfile ' \
              "(e.g. `pod '#{name}', '#{lockfile_reqs.map(&:requirement).join("', '")}'`) " \
              "or revert to a stable version by running `pod update #{name}`."
          elsif !conflict.existing
            conflict.requirements.values.flatten.each do |r|
              unless search_for(r).empty?
                message << "\n\nSpecs satisfying the `#{r}` dependency were found, " \
                  'but they required a higher minimum deployment target.'
              end
            end
          end
        end
      end
      raise Informative, message
    end

    def spec_is_platform_compatible?(dependency_graph, dependency, spec)
      all_predecessors = ->(vertex) do
        pred = vertex.predecessors
        pred + pred.map(&all_predecessors).reduce(Set.new, &:|) << vertex
      end
      vertex = dependency_graph.vertex_named(dependency.name)
      predecessors = all_predecessors[vertex].reject { |v| !dependency_graph.root_vertex_named(v.name) }
      platforms_to_satisfy = predecessors.flat_map(&:explicit_requirements).flat_map { |r| @platforms_by_dependency[r] }

      platforms_to_satisfy.all? do |platform_to_satisfy|
        spec.available_platforms.select { |spec_platform| spec_platform.name == platform_to_satisfy.name }.
          all? { |spec_platform| platform_to_satisfy.supports?(spec_platform) }
      end
    end

    def valid_dependencies_for_target_from_node(target, node)
      validate_platform(node.payload, target)
      dependency_nodes = node.outgoing_edges.select do |edge|
        edge_is_valid_for_target?(edge, target)
      end.map(&:destination)

      dependency_nodes + dependency_nodes.flat_map { |n| valid_dependencies_for_target_from_node(target, n) }
    end

    def edge_is_valid_for_target?(edge, target)
      dependencies_for_target_platform =
        edge.origin.payload.all_dependencies(target.platform).map(&:name)
      edge.requirements.any? do |dependency|
        dependencies_for_target_platform.include?(dependency.name)
      end
    end
  end
end
