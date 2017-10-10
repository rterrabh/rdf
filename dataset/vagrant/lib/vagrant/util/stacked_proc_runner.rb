module Vagrant
  module Util
    module StackedProcRunner
      def proc_stack
        @_proc_stack ||= []
      end

      def push_proc(&block)
        proc_stack << block
      end

      def run_procs!(*args)
        proc_stack.each do |proc|
          proc.call(*args)
        end
      end
    end
  end
end
