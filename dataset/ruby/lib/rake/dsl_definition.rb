require 'rake/file_utils_ext'

module Rake


  module DSL


    include FileUtilsExt
    private(*FileUtils.instance_methods(false))
    private(*FileUtilsExt.instance_methods(false))

    private

    def task(*args, &block) # :doc:
      Rake::Task.define_task(*args, &block)
    end

    def file(*args, &block) # :doc:
      Rake::FileTask.define_task(*args, &block)
    end

    def file_create(*args, &block)
      Rake::FileCreationTask.define_task(*args, &block)
    end

    def directory(*args, &block) # :doc:
      result = file_create(*args, &block)
      dir, _ = *Rake.application.resolve_args(args)
      dir = Rake.from_pathname(dir)
      Rake.each_dir_parent(dir) do |d|
        file_create d do |t|
          mkdir_p t.name unless File.exist?(t.name)
        end
      end
      result
    end

    def multitask(*args, &block) # :doc:
      Rake::MultiTask.define_task(*args, &block)
    end

    def namespace(name=nil, &block) # :doc:
      name = name.to_s if name.kind_of?(Symbol)
      name = name.to_str if name.respond_to?(:to_str)
      unless name.kind_of?(String) || name.nil?
        raise ArgumentError, "Expected a String or Symbol for a namespace name"
      end
      Rake.application.in_namespace(name, &block)
    end

    def rule(*args, &block) # :doc:
      Rake::Task.create_rule(*args, &block)
    end

    def desc(description) # :doc:
      Rake.application.last_description = description
    end

    def import(*fns) # :doc:
      fns.each do |fn|
        Rake.application.add_import(fn)
      end
    end
  end
  extend FileUtilsExt
end

self.extend Rake::DSL
