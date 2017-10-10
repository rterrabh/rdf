require 'rake/task.rb'
require 'rake/early_time'

module Rake

  class FileTask < Task

    def needed?
      ! File.exist?(name) || out_of_date?(timestamp) || @application.options.build_all
    end

    def timestamp
      if File.exist?(name)
        File.mtime(name.to_s)
      else
        Rake::LATE
      end
    end

    private

    def out_of_date?(stamp)
      @prerequisites.any? { |n| application[n, @scope].timestamp > stamp }
    end

    class << self
      def scope_name(scope, task_name)
        Rake.from_pathname(task_name)
      end
    end
  end
end
