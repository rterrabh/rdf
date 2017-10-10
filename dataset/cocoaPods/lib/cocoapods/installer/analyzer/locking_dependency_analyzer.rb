require 'molinillo/dependency_graph'

module Pod
  class Installer
    class Analyzer
      module LockingDependencyAnalyzer
        def self.generate_version_locking_dependencies(lockfile, pods_to_update)
          dependency_graph = Molinillo::DependencyGraph.new

          if lockfile
            explicit_dependencies = lockfile.to_hash['DEPENDENCIES'] || []
            explicit_dependencies.each do |string|
              dependency = Dependency.new(string)
              dependency_graph.add_root_vertex(dependency.name, nil)
            end

            pods = lockfile.to_hash['PODS'] || []
            pods.each do |pod|
              add_to_dependency_graph(pod, [], dependency_graph)
            end

            pods_to_update = pods_to_update.flat_map do |u|
              root_name = Specification.root_name(u).downcase
              dependency_graph.vertices.keys.select { |n| Specification.root_name(n).downcase == root_name }
            end

            pods_to_update.each do |u|
              dependency_graph.detach_vertex_named(u)
            end
          end

          dependency_graph
        end

        def self.unlocked_dependency_graph
          Molinillo::DependencyGraph.new
        end

        private

        def self.add_child_vertex_to_graph(dependency_string, parents, dependency_graph)
          dependency = Dependency.from_string(dependency_string)
          dependency_graph.add_child_vertex(dependency.name, parents.empty? ? dependency : nil, parents, nil)
          dependency
        end

        def self.add_to_dependency_graph(object, parents, dependency_graph)
          case object
          when String
            add_child_vertex_to_graph(object, parents, dependency_graph)
          when Hash
            object.each do |key, value|
              dependency = add_child_vertex_to_graph(key, parents, dependency_graph)
              value.each { |v| add_to_dependency_graph(v, [dependency.name], dependency_graph) }
            end
          end
        end
      end
    end
  end
end
