require 'json/version'
require 'json/generic_object'

module JSON
  class << self
    def [](object, opts = {})
      if object.respond_to? :to_str
        JSON.parse(object.to_str, opts)
      else
        JSON.generate(object, opts)
      end
    end

    attr_reader :parser

    def parser=(parser) # :nodoc:
      @parser = parser
      remove_const :Parser if JSON.const_defined_in?(self, :Parser)
      #nodyna <const_set-1522> <CS TRIVIAL (static values)>
      const_set :Parser, parser
    end

    def deep_const_get(path) # :nodoc:
      path.to_s.split(/::/).inject(Object) do |p, c|
        case
        when c.empty?                     then p
        #nodyna <const_get-1523> <CG COMPLEX (array)>
        when JSON.const_defined_in?(p, c) then p.const_get(c)
        else
          begin
            p.const_missing(c)
          rescue NameError => e
            raise ArgumentError, "can't get const #{path}: #{e}"
          end
        end
      end
    end

    def generator=(generator) # :nodoc:
      old, $VERBOSE = $VERBOSE, nil
      @generator = generator
      generator_methods = generator::GeneratorMethods
      for const in generator_methods.constants
        klass = deep_const_get(const)
        #nodyna <const_get-1524> <CG COMPLEX (array)>
        modul = generator_methods.const_get(const)
        #nodyna <class_eval-1525> <CE COMPLEX (block execution)>
        klass.class_eval do
          instance_methods(false).each do |m|
            m.to_s == 'to_json' and remove_method m
          end
          include modul
        end
      end
      self.state = generator::State
      #nodyna <const_set-1526> <CS TRIVIAL (static values)>
      const_set :State, self.state
      #nodyna <const_set-1527> <CS TRIVIAL (static values)>
      const_set :SAFE_STATE_PROTOTYPE, State.new
      #nodyna <const_set-1528> <CS TRIVIAL (static values)>
      const_set :FAST_STATE_PROTOTYPE, State.new(
        :indent         => '',
        :space          => '',
        :object_nl      => "",
        :array_nl       => "",
        :max_nesting    => false
      )
      #nodyna <const_set-1529> <CS TRIVIAL (static values)>
      const_set :PRETTY_STATE_PROTOTYPE, State.new(
        :indent         => '  ',
        :space          => ' ',
        :object_nl      => "\n",
        :array_nl       => "\n"
      )
    ensure
      $VERBOSE = old
    end

    attr_reader :generator

    attr_accessor :state

    attr_accessor :create_id
  end
  self.create_id = 'json_class'

  NaN           = 0.0/0

  Infinity      = 1.0/0

  MinusInfinity = -Infinity

  class JSONError < StandardError
    def self.wrap(exception)
      obj = new("Wrapped(#{exception.class}): #{exception.message.inspect}")
      obj.set_backtrace exception.backtrace
      obj
    end
  end

  class ParserError < JSONError; end

  class NestingError < ParserError; end

  class CircularDatastructure < NestingError; end

  class GeneratorError < JSONError; end
  UnparserError = GeneratorError

  class MissingUnicodeSupport < JSONError; end

  module_function

  def parse(source, opts = {})
    Parser.new(source, opts).parse
  end

  def parse!(source, opts = {})
    opts = {
      :max_nesting  => false,
      :allow_nan    => true
    }.update(opts)
    Parser.new(source, opts).parse
  end

  def generate(obj, opts = nil)
    if State === opts
      state, opts = opts, nil
    else
      state = SAFE_STATE_PROTOTYPE.dup
    end
    if opts
      if opts.respond_to? :to_hash
        opts = opts.to_hash
      elsif opts.respond_to? :to_h
        opts = opts.to_h
      else
        raise TypeError, "can't convert #{opts.class} into Hash"
      end
      state = state.configure(opts)
    end
    state.generate(obj)
  end

  alias unparse generate
  module_function :unparse

  def fast_generate(obj, opts = nil)
    if State === opts
      state, opts = opts, nil
    else
      state = FAST_STATE_PROTOTYPE.dup
    end
    if opts
      if opts.respond_to? :to_hash
        opts = opts.to_hash
      elsif opts.respond_to? :to_h
        opts = opts.to_h
      else
        raise TypeError, "can't convert #{opts.class} into Hash"
      end
      state.configure(opts)
    end
    state.generate(obj)
  end

  alias fast_unparse fast_generate
  module_function :fast_unparse

  def pretty_generate(obj, opts = nil)
    if State === opts
      state, opts = opts, nil
    else
      state = PRETTY_STATE_PROTOTYPE.dup
    end
    if opts
      if opts.respond_to? :to_hash
        opts = opts.to_hash
      elsif opts.respond_to? :to_h
        opts = opts.to_h
      else
        raise TypeError, "can't convert #{opts.class} into Hash"
      end
      state.configure(opts)
    end
    state.generate(obj)
  end

  alias pretty_unparse pretty_generate
  module_function :pretty_unparse

  class << self
    attr_accessor :load_default_options
  end
  self.load_default_options = {
    :max_nesting      => false,
    :allow_nan        => true,
    :quirks_mode      => true,
    :create_additions => true,
  }

  def load(source, proc = nil, options = {})
    opts = load_default_options.merge options
    if source.respond_to? :to_str
      source = source.to_str
    elsif source.respond_to? :to_io
      source = source.to_io.read
    elsif source.respond_to?(:read)
      source = source.read
    end
    if opts[:quirks_mode] && (source.nil? || source.empty?)
      source = 'null'
    end
    result = parse(source, opts)
    recurse_proc(result, &proc) if proc
    result
  end

  def recurse_proc(result, &proc)
    case result
    when Array
      result.each { |x| recurse_proc x, &proc }
      proc.call result
    when Hash
      result.each { |x, y| recurse_proc x, &proc; recurse_proc y, &proc }
      proc.call result
    else
      proc.call result
    end
  end

  alias restore load
  module_function :restore

  class << self
    attr_accessor :dump_default_options
  end
  self.dump_default_options = {
    :max_nesting => false,
    :allow_nan   => true,
    :quirks_mode => true,
  }

  def dump(obj, anIO = nil, limit = nil)
    if anIO and limit.nil?
      anIO = anIO.to_io if anIO.respond_to?(:to_io)
      unless anIO.respond_to?(:write)
        limit = anIO
        anIO = nil
      end
    end
    opts = JSON.dump_default_options
    limit and opts.update(:max_nesting => limit)
    result = generate(obj, opts)
    if anIO
      anIO.write result
      anIO
    else
      result
    end
  rescue JSON::NestingError
    raise ArgumentError, "exceed depth limit"
  end

  def self.swap!(string) # :nodoc:
    0.upto(string.size / 2) do |i|
      break unless string[2 * i + 1]
      string[2 * i], string[2 * i + 1] = string[2 * i + 1], string[2 * i]
    end
    string
  end

  if ::String.method_defined?(:encode)
    def self.iconv(to, from, string)
      string.encode(to, from)
    end
  else
    require 'iconv'
    def self.iconv(to, from, string)
      Iconv.conv(to, from, string)
    end
  end

  if ::Object.method(:const_defined?).arity == 1
    def self.const_defined_in?(modul, constant)
      modul.const_defined?(constant)
    end
  else
    def self.const_defined_in?(modul, constant)
      modul.const_defined?(constant, false)
    end
  end
end

module ::Kernel
  private

  def j(*objs)
    objs.each do |obj|
      puts JSON::generate(obj, :allow_nan => true, :max_nesting => false)
    end
    nil
  end

  def jj(*objs)
    objs.each do |obj|
      puts JSON::pretty_generate(obj, :allow_nan => true, :max_nesting => false)
    end
    nil
  end

  def JSON(object, *args)
    if object.respond_to? :to_str
      JSON.parse(object.to_str, args.first)
    else
      JSON.generate(object, args.first)
    end
  end
end

class ::Class
  def json_creatable?
    respond_to?(:json_create)
  end
end
