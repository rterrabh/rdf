require "resource"

module Language
  module Go
    def self.stage_deps(resources, target)
      resources.grep(Resource::Go) { |resource| resource.stage(target) }
    end
  end
end
