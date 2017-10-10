
require "irb/cmd/nop.rb"
require "irb/ext/change-ws.rb"

module IRB
  module ExtendCommand

    class CurrentWorkingWorkspace<Nop
      def execute(*obj)
        irb_context.main
      end
    end

    class ChangeWorkspace<Nop
      def execute(*obj)
        irb_context.change_workspace(*obj)
        irb_context.main
      end
    end
  end
end
