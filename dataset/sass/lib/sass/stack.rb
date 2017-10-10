module Sass
  class Stack

    class Frame
      attr_reader :filename

      attr_reader :line

      attr_reader :type

      attr_reader :name

      def initialize(filename, line, type, name = nil)
        @filename = filename
        @line = line
        @type = type
        @name = name
      end

      def is_import?
        type == :import
      end

      def is_mixin?
        type == :mixin
      end

      def is_base?
        type == :base
      end
    end

    attr_reader :frames

    def initialize
      @frames = []
    end

    def with_base(filename, line)
      with_frame(filename, line, :base) {yield}
    end

    def with_import(filename, line)
      with_frame(filename, line, :import) {yield}
    end

    def with_mixin(filename, line, name)
      with_frame(filename, line, :mixin, name) {yield}
    end

    def to_s
      Sass::Util.enum_with_index(Sass::Util.enum_cons(frames.reverse + [nil], 2)).
          map do |(frame, caller), i|
        "#{i == 0 ? "on" : "from"} line #{frame.line}" +
          " of #{frame.filename || "an unknown file"}" +
          (caller && caller.name ? ", in `#{caller.name}'" : "")
      end.join("\n")
    end

    private

    def with_frame(filename, line, type, name = nil)
      @frames.pop if @frames.last && @frames.last.type == :base
      @frames.push(Frame.new(filename, line, type, name))
      yield
    ensure
      @frames.pop unless type == :base && @frames.last && @frames.last.type != :base
    end
  end
end
