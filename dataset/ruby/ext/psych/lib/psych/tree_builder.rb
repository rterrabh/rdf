require 'psych/handler'

module Psych
  class TreeBuilder < Psych::Handler
    attr_reader :root

    def initialize
      @stack = []
      @last  = nil
      @root  = nil
    end

    %w{
      Sequence
      Mapping
    }.each do |node|
      #nodyna <class_eval-1476> <CE MODERATE (define methods)>
      class_eval %{
        def start_#{node.downcase}(anchor, tag, implicit, style)
          n = Nodes::#{node}.new(anchor, tag, implicit, style)
          @last.children << n
          push n
        end

        def end_#{node.downcase}
          pop
        end
      }
    end

    def start_document version, tag_directives, implicit
      n = Nodes::Document.new version, tag_directives, implicit
      @last.children << n
      push n
    end

    def end_document implicit_end = !streaming?
      @last.implicit_end = implicit_end
      pop
    end

    def start_stream encoding
      @root = Nodes::Stream.new(encoding)
      push @root
    end

    def end_stream
      pop
    end

    def scalar value, anchor, tag, plain, quoted, style
      s = Nodes::Scalar.new(value,anchor,tag,plain,quoted,style)
      @last.children << s
      s
    end

    def alias anchor
      @last.children << Nodes::Alias.new(anchor)
    end

    private
    def push value
      @stack.push value
      @last = value
    end

    def pop
      x = @stack.pop
      @last = @stack.last
      x
    end
  end
end
