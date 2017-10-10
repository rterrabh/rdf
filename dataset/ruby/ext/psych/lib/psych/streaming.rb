module Psych
  module Streaming
    module ClassMethods
      def new io
        #nodyna <const_get-1475> <CG TRIVIAL (static values)>
        emitter      = const_get(:Emitter).new(io)
        class_loader = ClassLoader.new
        ss           = ScalarScanner.new class_loader
        super(emitter, ss, {})
      end
    end

    def start encoding = Nodes::Stream::UTF8
      super.tap { yield self if block_given?  }
    ensure
      finish if block_given?
    end

    private
    def register target, obj
    end
  end
end
