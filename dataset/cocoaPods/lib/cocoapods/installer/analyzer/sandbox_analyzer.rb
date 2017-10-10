module Pod
  class Installer
    class Analyzer
      class SandboxAnalyzer
        attr_reader :sandbox

        attr_reader :specs

        attr_reader :update_mode

        alias_method :update_mode?, :update_mode

        attr_reader :lockfile

        def initialize(sandbox, specs, update_mode, lockfile = nil)
          @sandbox = sandbox
          @specs = specs
          @update_mode = update_mode
          @lockfile = lockfile
        end

        def analyze
          state = SpecsState.new
          if sandbox_manifest
            all_names = (resolved_pods + sandbox_pods).uniq.sort
            all_names.sort.each do |name|
              state.add_name(name, pod_state(name))
            end
          else
            state.added.concat(resolved_pods)
          end
          state
        end


        private


        def pod_state(pod)
          return :added   if pod_added?(pod)
          return :deleted if pod_deleted?(pod)
          return :changed if pod_changed?(pod)
          :unchanged
        end

        def pod_added?(pod)
          return true if resolved_pods.include?(pod) && !sandbox_pods.include?(pod)
          return true unless folder_exist?(pod)
          false
        end

        def pod_deleted?(pod)
          return true if !resolved_pods.include?(pod) && sandbox_pods.include?(pod)
          false
        end

        def pod_changed?(pod)
          spec = root_spec(pod)
          return true if spec.version != sandbox_version(pod)
          return true if spec.checksum != sandbox_checksum(pod)
          return true if resolved_spec_names(pod) != sandbox_spec_names(pod)
          return true if sandbox.predownloaded?(pod)
          return true if folder_empty?(pod)
          return true if sandbox.head_pod?(pod) != sandbox_head_version?(pod)
          if update_mode
            return true if sandbox.head_pod?(pod)
          end
          false
        end


        private


        def sandbox_manifest
          sandbox.manifest || lockfile
        end


        def resolved_pods
          specs.map { |spec| spec.root.name }.uniq
        end

        def sandbox_pods
          sandbox_manifest.pod_names.map { |name| Specification.root_name(name) }.uniq
        end

        def resolved_spec_names(pod)
          specs.select { |s| s.root.name == pod }.map(&:name).uniq.sort
        end

        def sandbox_spec_names(pod)
          sandbox_manifest.pod_names.select { |name| Specification.root_name(name) == pod }.uniq.sort
        end

        def root_spec(pod)
          specs.find { |s| s.root.name == pod }.root
        end


        def sandbox_version(pod)
          sandbox_manifest.version(pod)
        end

        def sandbox_checksum(pod)
          sandbox_manifest.checksum(pod)
        end

        def sandbox_head_version?(pod)
          sandbox_version(pod).head? == true
        end


        def folder_exist?(pod)
          sandbox.pod_dir(pod).exist?
        end

        def folder_empty?(pod)
          Dir.glob(sandbox.pod_dir(pod) + '*').empty?
        end

      end
    end
  end
end
