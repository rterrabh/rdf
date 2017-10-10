module XMLRPC # :nodoc:


  module Marshallable
  end


  module ParserWriterChooseMixin

    def set_writer(writer)
      @create = Create.new(writer)
      self
    end

    def set_parser(parser)
      @parser = parser
      self
    end

    private

    def create
      if @create.nil? then
        set_writer(Config::DEFAULT_WRITER.new)
      end
      @create
    end

    def parser
      if @parser.nil? then
        set_parser(Config::DEFAULT_PARSER.new)
      end
      @parser
    end

  end # module ParserWriterChooseMixin


  module Service

  class BasicInterface
    attr_reader :prefix, :methods

    def initialize(prefix)
      @prefix = prefix
      @methods = []
    end

    def add_method(sig, help=nil, meth_name=nil)
      mname = nil
      sig = [sig] if sig.kind_of? String

      sig = sig.collect do |s|
        name, si = parse_sig(s)
        raise "Wrong signatures!" if mname != nil and name != mname
        mname = name
        si
      end

      @methods << [mname, meth_name || mname, sig, help]
    end

    private

    def parse_sig(sig)
      if sig =~ /^\s*(\w+)\s+([^(]+)(\(([^)]*)\))?\s*$/
        params = [$1]
        name   = $2.strip
        $4.split(",").each {|i| params << i.strip} if $4 != nil
        return name, params
      else
        raise "Syntax error in signature"
      end
    end

  end # class BasicInterface

  class Interface < BasicInterface
    def initialize(prefix, &p)
      raise "No interface specified" if p.nil?
      super(prefix)
      #nodyna <instance_eval-2016> <IEV COMPLEX (block execution)>
      instance_eval(&p)
    end

    def get_methods(obj, delim=".")
      prefix = @prefix + delim
      @methods.collect { |name, meth, sig, help|
        [prefix + name.to_s, obj.method(meth).to_proc, sig, help]
      }
    end

    private

    def meth(*a)
      add_method(*a)
    end

  end # class Interface

  class PublicInstanceMethodsInterface < BasicInterface
    def initialize(prefix)
      super(prefix)
    end

    def get_methods(obj, delim=".")
      prefix = @prefix + delim
      obj.class.public_instance_methods(false).collect { |name|
        [prefix + name.to_s, obj.method(name).to_proc, nil, nil]
      }
    end
  end


  end # module Service


  def self.interface(prefix, &p)
    Service::Interface.new(prefix, &p)
  end

  def self.iPIMethods(prefix)
    Service::PublicInstanceMethodsInterface.new(prefix)
  end


  module ParseContentType
    def parse_content_type(str)
      a, *b = str.split(";")
      return a.strip.downcase, *b
    end
  end

end # module XMLRPC

