module ActiveSupport
  class OrderedOptions < Hash
    alias_method :_get, :[] # preserve the original #[] method
    protected :_get # make it protected

    def []=(key, value)
      super(key.to_sym, value)
    end

    def [](key)
      super(key.to_sym)
    end

    def method_missing(name, *args)
      name_string = name.to_s
      if name_string.chomp!('=')
        self[name_string] = args.first
      else
        self[name]
      end
    end

    def respond_to_missing?(name, include_private)
      true
    end
  end

  class InheritableOptions < OrderedOptions
    def initialize(parent = nil)
      if parent.kind_of?(OrderedOptions)
        super() { |h,k| parent._get(k) }
      elsif parent
        super() { |h,k| parent[k] }
      else
        super()
      end
    end

    def inheritable_copy
      self.class.new(self)
    end
  end
end
