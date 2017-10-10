module IRB
  module ExtendCommand
    class Nop


      def self.execute(conf, *opts)
        command = new(conf)
        command.execute(*opts)
      end

      def initialize(conf)
        @irb_context = conf
      end

      attr_reader :irb_context

      def irb
        @irb_context.irb
      end

      def execute(*opts)
      end
    end
  end
end
