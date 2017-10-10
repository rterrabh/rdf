module Psych
  class Handler
    class DumperOptions
      attr_accessor :line_width, :indentation, :canonical

      def initialize
        @line_width  = 0
        @indentation = 2
        @canonical   = false
      end
    end

    OPTIONS = DumperOptions.new

    EVENTS = [ :alias,
               :empty,
               :end_document,
               :end_mapping,
               :end_sequence,
               :end_stream,
               :scalar,
               :start_document,
               :start_mapping,
               :start_sequence,
               :start_stream ]

    def start_stream encoding
    end

    def start_document version, tag_directives, implicit
    end

    def end_document implicit
    end

    def alias anchor
    end

    def scalar value, anchor, tag, plain, quoted, style
    end


    def start_sequence anchor, tag, implicit, style
    end

    def end_sequence
    end


    def start_mapping anchor, tag, implicit, style
    end

    def end_mapping
    end

    def empty
    end

    def end_stream
    end

    def streaming?
      false
    end
  end
end
