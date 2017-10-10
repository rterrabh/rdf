
class MockExpectationError < StandardError; end # :nodoc:


module MiniTest # :nodoc:


  class Mock
    alias :__respond_to? :respond_to?

    skip_methods = %w(object_id respond_to_missing? inspect === to_s)

    instance_methods.each do |m|
      undef_method m unless skip_methods.include?(m.to_s) || m =~ /^__/
    end

    def initialize # :nodoc:
      @expected_calls = Hash.new { |calls, name| calls[name] = [] }
      @actual_calls   = Hash.new { |calls, name| calls[name] = [] }
    end


    def expect(name, retval, args=[], &blk)
      if block_given?
        raise ArgumentError, "args ignored when block given" unless args.empty?
        @expected_calls[name] << { :retval => retval, :block => blk }
      else
        raise ArgumentError, "args must be an array" unless Array === args
        @expected_calls[name] << { :retval => retval, :args => args }
      end
      self
    end

    def __call name, data # :nodoc:
      case data
      when Hash then
        "#{name}(#{data[:args].inspect[1..-2]}) => #{data[:retval].inspect}"
      else
        data.map { |d| __call name, d }.join ", "
      end
    end


    def verify
      @expected_calls.each do |name, calls|
        calls.each do |expected|
          msg1 = "expected #{__call name, expected}"
          msg2 = "#{msg1}, got [#{__call name, @actual_calls[name]}]"

          raise MockExpectationError, msg2 if
            @actual_calls.has_key?(name) and
            not @actual_calls[name].include?(expected)

          raise MockExpectationError, msg1 unless
            @actual_calls.has_key?(name) and
            @actual_calls[name].include?(expected)
        end
      end
      true
    end

    def method_missing(sym, *args) # :nodoc:
      unless @expected_calls.has_key?(sym) then
        raise NoMethodError, "unmocked method %p, expected one of %p" %
          [sym, @expected_calls.keys.sort_by(&:to_s)]
      end

      index = @actual_calls[sym].length
      expected_call = @expected_calls[sym][index]

      unless expected_call then
        raise MockExpectationError, "No more expects available for %p: %p" %
          [sym, args]
      end

      expected_args, retval, val_block =
        expected_call.values_at(:args, :retval, :block)

      if val_block then
        raise MockExpectationError, "mocked method %p failed block w/ %p" %
          [sym, args] unless val_block.call(args)

        @actual_calls[sym] << expected_call
        return retval
      end

      if expected_args.size != args.size then
        raise ArgumentError, "mocked method %p expects %d arguments, got %d" %
          [sym, expected_args.size, args.size]
      end

      fully_matched = expected_args.zip(args).all? { |mod, a|
        mod === a or mod == a
      }

      unless fully_matched then
        raise MockExpectationError, "mocked method %p called with unexpected arguments %p" %
          [sym, args]
      end

      @actual_calls[sym] << {
        :retval => retval,
        :args => expected_args.zip(args).map { |mod, a| mod === a ? mod : a }
      }

      retval
    end

    def respond_to?(sym, include_private = false) # :nodoc:
      return true if @expected_calls.has_key?(sym.to_sym)
      return __respond_to?(sym, include_private)
    end
  end
end

class Object # :nodoc:


  def stub name, val_or_callable, &block
    new_name = "__minitest_stub__#{name}"

    metaclass = class << self; self; end

    if respond_to? name and not methods.map(&:to_s).include? name.to_s then
      #nodyna <send-1432> <SD MODERATE (private methods)>
      #nodyna <define_method-1433> <DM COMPLEX (events)>
      metaclass.send :define_method, name do |*args|
        super(*args)
      end
    end

    #nodyna <send-1434> <SD MODERATE (private methods)>
    metaclass.send :alias_method, new_name, name

    #nodyna <send-1435> <SD MODERATE (private methods)>
    #nodyna <define_method-1436> <DM COMPLEX (events)>
    metaclass.send :define_method, name do |*args|
      if val_or_callable.respond_to? :call then
        val_or_callable.call(*args)
      else
        val_or_callable
      end
    end

    yield self
  ensure
    #nodyna <send-1437> <SD MODERATE (private methods)>
    metaclass.send :undef_method, name
    #nodyna <send-1438> <SD MODERATE (private methods)>
    metaclass.send :alias_method, name, new_name
    #nodyna <send-1439> <SD MODERATE (private methods)>
    metaclass.send :undef_method, new_name
  end
end
