module Rake

  class MultiTask < Task
    private
    def invoke_prerequisites(task_args, invocation_chain) # :nodoc:
      invoke_prerequisites_concurrently(task_args, invocation_chain)
    end
  end

end
