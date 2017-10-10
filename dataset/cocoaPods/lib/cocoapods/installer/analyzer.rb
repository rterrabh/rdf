module Pod
  class Installer
    class Analyzer
      include Config::Mixin

      autoload :AnalysisResult,            'cocoapods/installer/analyzer/analysis_result'
      autoload :SandboxAnalyzer,           'cocoapods/installer/analyzer/sandbox_analyzer'
      autoload :SpecsState,                'cocoapods/installer/analyzer/specs_state'
      autoload :LockingDependencyAnalyzer, 'cocoapods/installer/analyzer/locking_dependency_analyzer'
      autoload :TargetInspectionResult,    'cocoapods/installer/analyzer/target_inspection_result'
      autoload :TargetInspector,           'cocoapods/installer/analyzer/target_inspector'

      attr_reader :sandbox

      attr_reader :podfile

      attr_reader :lockfile

      def initialize(sandbox, podfile, lockfile = nil)
        @sandbox  = sandbox
        @podfile  = podfile
        @lockfile = lockfile

        @update = false
        @allow_pre_downloads = true
      end

      def analyze(allow_fetches = true)
        validate_podfile!
        validate_lockfile_version!
        @result = AnalysisResult.new
        if config.integrate_targets?
          @result.target_inspections = inspect_targets_to_integrate
        else
          verify_platforms_specified!
        end
        @result.podfile_state = generate_podfile_state
        @locked_dependencies  = generate_version_locking_dependencies

        store_existing_checkout_options
        fetch_external_sources if allow_fetches
        @result.specs_by_target = validate_platforms(resolve_dependencies)
        @result.specifications  = generate_specifications
        @result.targets         = generate_targets
        @result.sandbox_state   = generate_sandbox_state
        @result
      end

      attr_accessor :result

      def needs_install?
        analysis_result = analyze(false)
        podfile_needs_install?(analysis_result) || sandbox_needs_install?(analysis_result)
      end

      def podfile_needs_install?(analysis_result)
        state = analysis_result.podfile_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end

      def sandbox_needs_install?(analysis_result)
        state = analysis_result.sandbox_state
        needing_install = state.added + state.changed + state.deleted
        !needing_install.empty?
      end



      attr_accessor :update

      def update_mode?
        update != nil
      end

      def update_mode
        if !update
          :none
        elsif update == true
          :all
        elsif !update[:pods].nil?
          :selected
        end
      end

      attr_accessor :allow_pre_downloads
      alias_method :allow_pre_downloads?, :allow_pre_downloads


      private

      def validate_podfile!
        validator = Installer::PodfileValidator.new(podfile)
        validator.validate

        unless validator.valid?
          raise Informative, validator.message
        end
      end


      def validate_lockfile_version!
        if lockfile && lockfile.cocoapods_version > Version.new(VERSION)
          STDERR.puts '[!] The version of CocoaPods used to generate ' \
            "the lockfile (#{lockfile.cocoapods_version}) is "\
            "higher than the version of the current executable (#{VERSION}). " \
            'Incompatibility issues may arise.'.yellow
        end
      end

      def generate_podfile_state
        if lockfile
          pods_state = nil
          UI.section 'Finding Podfile changes' do
            pods_by_state = lockfile.detect_changes_with_podfile(podfile)
            pods_state = SpecsState.new(pods_by_state)
            pods_state.print
          end
          pods_state
        else
          state = SpecsState.new
          state.added.concat(podfile.dependencies.map(&:name).uniq)
          state
        end
      end

      public

      def update_repositories
        sources.each do |source|
          if SourcesManager.git_repo?(source.repo)
            SourcesManager.update(source.name)
          else
            UI.message "Skipping `#{source.name}` update because the repository is not a git source repository."
          end
        end
      end

      private

      def generate_targets
        pod_targets = generate_pod_targets(result.specs_by_target)
        result.specs_by_target.map do |target_definition, _|
          generate_target(target_definition, pod_targets)
        end
      end

      def generate_target(target_definition, pod_targets)
        target = AggregateTarget.new(target_definition, sandbox)
        target.host_requires_frameworks |= target_definition.uses_frameworks?

        if config.integrate_targets?
          target_inspection = result.target_inspections[target_definition]
          target.user_project_path = target_inspection.project_path
          target.client_root = target.user_project_path.dirname
          target.user_target_uuids = target_inspection.project_target_uuids
          target.user_build_configurations = target_inspection.build_configurations
          target.archs = target_inspection.archs
        else
          target.client_root = config.installation_root
          target.user_target_uuids = []
          target.user_build_configurations = target_definition.build_configurations || { 'Release' => :release, 'Debug' => :debug }
          if target_definition.platform.name == :osx
            target.archs = '$(ARCHS_STANDARD_64_BIT)'
          end
        end

        target.pod_targets = pod_targets.select do |pod_target|
          pod_target.target_definitions.include?(target_definition)
        end
        target
      end

      def generate_pod_targets(specs_by_target)
        if config.deduplicate_targets?
          all_specs = specs_by_target.flat_map do |target_definition, dependent_specs|
            dependent_specs.group_by(&:root).map do |root_spec, specs|
              [root_spec, specs, target_definition]
            end
          end

          distinct_targets = all_specs.each_with_object({}) do |dependency, hash|
            root_spec, specs, target_definition = *dependency
            hash[root_spec] ||= {}
            (hash[root_spec][[specs, target_definition.platform]] ||= []) << target_definition
          end

          pod_targets = distinct_targets.flat_map do |_, targets_by_distinctors|
            if targets_by_distinctors.count > 1
              targets_by_distinctors.map do |distinctor, target_definitions|
                specs, _ = *distinctor
                generate_pod_target(target_definitions, specs, :scoped => true)
              end
            else
              (specs, _), target_definitions = targets_by_distinctors.first
              generate_pod_target(target_definitions, specs)
            end
          end

          pod_targets.flat_map do |target|
            dependent_targets = transitive_dependencies_for_pod_target(target, pod_targets)
            target.dependent_targets = dependent_targets
            if dependent_targets.any?(&:scoped?)
              target.scoped
            else
              target
            end
          end
        else
          pod_targets = specs_by_target.flat_map do |target_definition, specs|
            grouped_specs = specs.group_by.group_by(&:root).values.uniq
            grouped_specs.flat_map do |pod_specs|
              generate_pod_target([target_definition], pod_specs, :scoped => true)
            end
          end
          pod_targets.each do |target|
            target.dependent_targets = transitive_dependencies_for_pod_target(target, pod_targets)
          end
        end
      end

      def transitive_dependencies_for_pod_target(pod_target, targets)
        if targets.any?
          dependent_targets = pod_target.dependencies.flat_map do |dep|
            next [] if pod_target.pod_name == dep
            targets.select { |t| t.pod_name == dep }
          end
          remaining_targets = targets - dependent_targets
          dependent_targets += dependent_targets.flat_map do |target|
            transitive_dependencies_for_pod_target(target, remaining_targets)
          end
          dependent_targets.uniq
        else
          []
        end
      end

      def generate_pod_target(target_definitions, pod_specs, scoped: false)
        pod_target = PodTarget.new(pod_specs, target_definitions, sandbox, scoped)

        if config.integrate_targets?
          target_inspections = result.target_inspections.select { |t, _| target_definitions.include?(t) }.values
          pod_target.user_build_configurations = target_inspections.map(&:build_configurations).reduce({}, &:merge)
          pod_target.archs = target_inspections.flat_map(&:archs).compact.uniq.sort
        else
          pod_target.user_build_configurations = {}
          if target_definitions.first.platform.name == :osx
            pod_target.archs = '$(ARCHS_STANDARD_64_BIT)'
          end
        end

        pod_target
      end

      def generate_version_locking_dependencies
        if update_mode == :all || !lockfile
          LockingDependencyAnalyzer.unlocked_dependency_graph
        else
          pods_to_update = result.podfile_state.changed + result.podfile_state.deleted
          pods_to_update += update[:pods] if update_mode == :selected
          pods_to_update += podfile.dependencies.select(&:local?).map(&:name)
          LockingDependencyAnalyzer.generate_version_locking_dependencies(lockfile, pods_to_update)
        end
      end

      def fetch_external_sources
        return unless allow_pre_downloads?

        verify_no_pods_with_different_sources!
        unless dependencies_to_fetch.empty?
          UI.section 'Fetching external sources' do
            dependencies_to_fetch.sort.each do |dependency|
              fetch_external_source(dependency, !pods_to_fetch.include?(dependency.name))
            end
          end
        end
      end

      def verify_no_pods_with_different_sources!
        deps_with_different_sources = podfile.dependencies.group_by(&:root_name).
          select { |_root_name, dependencies| dependencies.map(&:external_source).uniq.count > 1 }
        deps_with_different_sources.each do |root_name, dependencies|
          raise Informative, 'There are multiple dependencies with different ' \
          "sources for `#{root_name}` in #{UI.path podfile.defined_in_file}:" \
          "\n\n- #{dependencies.map(&:to_s).join("\n- ")}"
        end
      end

      def fetch_external_source(dependency, use_lockfile_options)
        checkout_options = lockfile.checkout_options_for_pod_named(dependency.root_name) if lockfile
        if checkout_options && use_lockfile_options
          source = ExternalSources.from_params(checkout_options, dependency, podfile.defined_in_file)
        else
          source = ExternalSources.from_dependency(dependency, podfile.defined_in_file)
        end
        source.fetch(sandbox)
      end

      def dependencies_to_fetch
        @deps_to_fetch ||= begin
          deps_to_fetch = []
          deps_with_external_source = podfile.dependencies.select(&:external_source)

          if update_mode == :all
            deps_to_fetch = deps_with_external_source
          else
            deps_to_fetch = deps_with_external_source.select { |dep| pods_to_fetch.include?(dep.name) }
            deps_to_fetch_if_needed = deps_with_external_source.select { |dep| result.podfile_state.unchanged.include?(dep.name) }
            deps_to_fetch += deps_to_fetch_if_needed.select do |dep|
              sandbox.specification(dep.name).nil? ||
                !dep.external_source[:local].nil? ||
                !dep.external_source[:path].nil? ||
                !sandbox.pod_dir(dep.root_name).directory? ||
                checkout_requires_update?(dep)
            end
          end
          deps_to_fetch.uniq(&:root_name)
        end
      end

      def checkout_requires_update?(dependency)
        return true unless lockfile && sandbox.manifest
        locked_checkout_options = lockfile.checkout_options_for_pod_named(dependency.root_name)
        sandbox_checkout_options = sandbox.manifest.checkout_options_for_pod_named(dependency.root_name)
        locked_checkout_options != sandbox_checkout_options
      end

      def pods_to_fetch
        @pods_to_fetch ||= begin
          pods_to_fetch = result.podfile_state.added + result.podfile_state.changed
          if update_mode == :selected
            pods_to_fetch += update[:pods]
          elsif update_mode == :all
            pods_to_fetch += result.podfile_state.unchanged + result.podfile_state.deleted
          end
          pods_to_fetch
        end
      end

      def store_existing_checkout_options
        podfile.dependencies.select(&:external_source).each do |dep|
          if checkout_options = lockfile && lockfile.checkout_options_for_pod_named(dep.root_name)
            sandbox.store_checkout_source(dep.root_name, checkout_options)
          end
        end
      end

      def resolve_dependencies
        duplicate_dependencies = podfile.dependencies.group_by(&:name).
          select { |_name, dependencies| dependencies.count > 1 }
        duplicate_dependencies.each do |name, dependencies|
          UI.warn "There are duplicate dependencies on `#{name}` in #{UI.path podfile.defined_in_file}:\n\n" \
           "- #{dependencies.map(&:to_s).join("\n- ")}"
        end

        specs_by_target = nil
        UI.section "Resolving dependencies of #{UI.path(podfile.defined_in_file) || 'Podfile'}" do
          resolver = Resolver.new(sandbox, podfile, locked_dependencies, sources)
          specs_by_target = resolver.resolve
          specs_by_target.values.flatten(1).each(&:validate_cocoapods_version)
        end
        specs_by_target
      end

      def validate_platforms(specs_by_target)
        specs_by_target.each do |target, specs|
          specs.each do |spec|
            unless spec.available_platforms.any? { |p| target.platform.supports?(p) }
              UI.warn "The platform of the target `#{target.name}` "     \
                "(#{target.platform}) may not be compatible with `#{spec}` which has "  \
                "a minimum requirement of #{spec.available_platforms.join(' - ')}."
            end
          end
        end
      end

      def generate_specifications
        result.specs_by_target.values.flatten.uniq
      end

      def generate_sandbox_state
        sandbox_state = nil
        UI.section 'Comparing resolved specification to the sandbox manifest' do
          sandbox_analyzer = SandboxAnalyzer.new(sandbox, result.specifications, update_mode?, lockfile)
          sandbox_state = sandbox_analyzer.analyze
          sandbox_state.print
        end
        sandbox_state
      end



      attr_reader :locked_dependencies


      public

      def sources
        @sources ||= begin
          sources = podfile.sources
          if sources.empty?
            url = 'https://github.com/CocoaPods/Specs.git'
            [SourcesManager.find_or_create_source_with_url(url)]
          else
            sources.map do |source_url|
              SourcesManager.find_or_create_source_with_url(source_url)
            end
          end
        end
      end


      private


      def verify_platforms_specified!
        unless config.integrate_targets?
          podfile.target_definition_list.each do |target_definition|
            unless target_definition.platform
              raise Informative, 'It is necessary to specify the platform in the Podfile if not integrating.'
            end
          end
        end
      end

      def inspect_targets_to_integrate
        inspection_result = {}
        UI.section 'Inspecting targets to integrate' do
          podfile.target_definition_list.each do |target_definition|
            inspector = TargetInspector.new(target_definition, config.installation_root)
            results = inspector.compute_results
            inspection_result[target_definition] = results
            UI.message('Using `ARCHS` setting to build architectures of ' \
              "target `#{target_definition.label}`: (`#{results.archs.join('`, `')}`)")
          end
        end
        inspection_result
      end
    end
  end
end
