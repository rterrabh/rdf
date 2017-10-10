module Resque
  module Plugin
    extend self

    LintError = Class.new(RuntimeError)

    def lint(plugin)
      hooks = before_hooks(plugin) + around_hooks(plugin) + after_hooks(plugin)

      hooks.each do |hook|
        if hook =~ /perform$/
          raise LintError, "#{plugin}.#{hook} is not namespaced"
        end
      end

      failure_hooks(plugin).each do |hook|
        if hook =~ /failure$/
          raise LintError, "#{plugin}.#{hook} is not namespaced"
        end
      end
    end

    def before_hooks(job)
      job.methods.grep(/^before_perform/).sort
    end

    def around_hooks(job)
      job.methods.grep(/^around_perform/).sort
    end

    def after_hooks(job)
      job.methods.grep(/^after_perform/).sort
    end

    def failure_hooks(job)
      job.methods.grep(/^on_failure/).sort
    end

    def after_enqueue_hooks(job)
      job.methods.grep(/^after_enqueue/).sort
    end

    def before_enqueue_hooks(job)
      job.methods.grep(/^before_enqueue/).sort
    end

    def after_dequeue_hooks(job)
      job.methods.grep(/^after_dequeue/).sort
    end

    def before_dequeue_hooks(job)
      job.methods.grep(/^before_dequeue/).sort
    end
  end
end
