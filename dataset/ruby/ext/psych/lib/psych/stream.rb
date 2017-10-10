module Psych
  class Stream < Psych::Visitors::YAMLTree
    class Emitter < Psych::Emitter # :nodoc:
      def end_document implicit_end = !streaming?
        super
      end

      def streaming?
        true
      end
    end

    include Psych::Streaming
    extend Psych::Streaming::ClassMethods
  end
end
