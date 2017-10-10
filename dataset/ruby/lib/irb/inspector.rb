
module IRB # :nodoc:


  def IRB::Inspector(inspect, init = nil)
    Inspector.new(inspect, init)
  end

  class Inspector
    INSPECTORS = {}

    def self.keys_with_inspector(inspector)
      INSPECTORS.select{|k,v| v == inspector}.collect{|k, v| k}
    end

    def self.def_inspector(key, arg=nil, &block)
      if block_given?
        inspector = IRB::Inspector(block, arg)
      else
        inspector = arg
      end

      case key
      when Array
        for k in key
          def_inspector(k, inspector)
        end
      when Symbol
        INSPECTORS[key] = inspector
        INSPECTORS[key.to_s] = inspector
      when String
        INSPECTORS[key] = inspector
        INSPECTORS[key.intern] = inspector
      else
        INSPECTORS[key] = inspector
      end
    end

    def initialize(inspect_proc, init_proc = nil)
      @init = init_proc
      @inspect = inspect_proc
    end

    def init
      @init.call if @init
    end

    def inspect_value(v)
      @inspect.call(v)
    end
  end

  Inspector.def_inspector([false, :to_s, :raw]){|v| v.to_s}
  Inspector.def_inspector([true, :p, :inspect]){|v|
    begin
      v.inspect
    rescue NoMethodError
      puts "(Object doesn't support #inspect)"
    end
  }
  Inspector.def_inspector([:pp, :pretty_inspect], proc{require "pp"}){|v| v.pretty_inspect.chomp}
  Inspector.def_inspector([:yaml, :YAML], proc{require "yaml"}){|v|
    begin
      YAML.dump(v)
    rescue
      puts "(can't dump yaml. use inspect)"
      v.inspect
    end
  }

  Inspector.def_inspector([:marshal, :Marshal, :MARSHAL, Marshal]){|v|
    Marshal.dump(v)
  }
end





