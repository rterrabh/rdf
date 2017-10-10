module Psych
  class Coder
    attr_accessor :tag, :style, :implicit, :object
    attr_reader   :type, :seq

    def initialize tag
      @map      = {}
      @seq      = []
      @implicit = false
      @type     = :map
      @tag      = tag
      @style    = Psych::Nodes::Mapping::BLOCK
      @scalar   = nil
      @object   = nil
    end

    def scalar *args
      if args.length > 0
        warn "#{caller[0]}: Coder#scalar(a,b,c) is deprecated" if $VERBOSE
        @tag, @scalar, _ = args
        @type = :scalar
      end
      @scalar
    end

    def map tag = @tag, style = @style
      @tag   = tag
      @style = style
      yield self if block_given?
      @map
    end

    def represent_scalar tag, value
      self.tag    = tag
      self.scalar = value
    end

    def represent_seq tag, list
      @tag = tag
      self.seq = list
    end

    def represent_map tag, map
      @tag = tag
      self.map = map
    end

    def represent_object tag, obj
      @tag    = tag
      @type   = :object
      @object = obj
    end

    def scalar= value
      @type   = :scalar
      @scalar = value
    end

    def map= map
      @type = :map
      @map  = map
    end

    def []= k, v
      @type = :map
      @map[k] = v
    end
    alias :add :[]=

    def [] k
      @type = :map
      @map[k]
    end

    def seq= list
      @type = :seq
      @seq  = list
    end
  end
end
