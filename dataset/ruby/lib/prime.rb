
require "singleton"
require "forwardable"

class Integer
  def Integer.from_prime_division(pd)
    Prime.int_from_prime_division(pd)
  end

  def prime_division(generator = Prime::Generator23.new)
    Prime.prime_division(self, generator)
  end

  def prime?
    Prime.prime?(self)
  end

  def Integer.each_prime(ubound, &block) # :yields: prime
    Prime.each(ubound, &block)
  end
end


class Prime
  include Enumerable
  @the_instance = Prime.new

  def initialize
    @generator = EratosthenesGenerator.new
    extend OldCompatibility
    warn "Prime::new is obsolete. use Prime::instance or class methods of Prime."
  end

  class << self
    extend Forwardable
    include Enumerable
    def instance; @the_instance end

    def method_added(method) # :nodoc:
      (class<< self;self;end).def_delegator :instance, method
    end
  end

  def each(ubound = nil, generator = EratosthenesGenerator.new, &block)
    generator.upper_bound = ubound
    generator.each(&block)
  end


  def prime?(value, generator = Prime::Generator23.new)
    return false if value < 2
    for num in generator
      q,r = value.divmod num
      return true if q < num
      return false if r == 0
    end
  end

  def int_from_prime_division(pd)
    pd.inject(1){|value, (prime, index)|
      value * prime**index
    }
  end

  def prime_division(value, generator = Prime::Generator23.new)
    raise ZeroDivisionError if value == 0
    if value < 0
      value = -value
      pv = [[-1, 1]]
    else
      pv = []
    end
    for prime in generator
      count = 0
      while (value1, mod = value.divmod(prime)
             mod) == 0
        value = value1
        count += 1
      end
      if count != 0
        pv.push [prime, count]
      end
      break if value1 <= prime
    end
    if value > 1
      pv.push [value, 1]
    end
    return pv
  end

  class PseudoPrimeGenerator
    include Enumerable

    def initialize(ubound = nil)
      @ubound = ubound
    end

    def upper_bound=(ubound)
      @ubound = ubound
    end
    def upper_bound
      @ubound
    end

    def succ
      raise NotImplementedError, "need to define `succ'"
    end

    def next
      raise NotImplementedError, "need to define `next'"
    end

    def rewind
      raise NotImplementedError, "need to define `rewind'"
    end

    def each
      return self.dup unless block_given?
      if @ubound
        last_value = nil
        loop do
          prime = succ
          break last_value if prime > @ubound
          last_value = yield prime
        end
      else
        loop do
          yield succ
        end
      end
    end

    alias with_index each_with_index

    def with_object(obj)
      return enum_for(:with_object) unless block_given?
      each do |prime|
        yield prime, obj
      end
    end
  end

  class EratosthenesGenerator < PseudoPrimeGenerator
    def initialize
      @last_prime_index = -1
      super
    end

    def succ
      @last_prime_index += 1
      EratosthenesSieve.instance.get_nth_prime(@last_prime_index)
    end
    def rewind
      initialize
    end
    alias next succ
  end

  class TrialDivisionGenerator<PseudoPrimeGenerator
    def initialize
      @index = -1
      super
    end

    def succ
      TrialDivision.instance[@index += 1]
    end
    def rewind
      initialize
    end
    alias next succ
  end

  class Generator23<PseudoPrimeGenerator
    def initialize
      @prime = 1
      @step = nil
      super
    end

    def succ
      if (@step)
        @prime += @step
        @step = 6 - @step
      else
        case @prime
        when 1; @prime = 2
        when 2; @prime = 3
        when 3; @prime = 5; @step = 2
        end
      end
      return @prime
    end
    alias next succ
    def rewind
      initialize
    end
  end

  class TrialDivision
    include Singleton

    def initialize # :nodoc:

      @primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101]
      @next_to_check = 103            # @primes[-1] - @primes[-1] % 6 + 7
      @ulticheck_index = 3            # @primes.index(@primes.reverse.find {|n|
      @ulticheck_next_squared = 121   # @primes[@ulticheck_index + 1] ** 2
    end

    def cache
      return @primes
    end
    alias primes cache
    alias primes_so_far cache

    def [](index)
      while index >= @primes.length
        if @next_to_check + 4 > @ulticheck_next_squared
          @ulticheck_index += 1
          @ulticheck_next_squared = @primes.at(@ulticheck_index + 1) ** 2
        end

        @primes.push @next_to_check if @primes[2..@ulticheck_index].find {|prime| @next_to_check % prime == 0 }.nil?
        @next_to_check += 4
        @primes.push @next_to_check if @primes[2..@ulticheck_index].find {|prime| @next_to_check % prime == 0 }.nil?
        @next_to_check += 2
      end
      return @primes[index]
    end
  end

  class EratosthenesSieve
    include Singleton

    def initialize
      @primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101]
      @max_checked = @primes.last + 1
    end

    def get_nth_prime(n)
      compute_primes while @primes.size <= n
      @primes[n]
    end

    private
    def compute_primes
      max_segment_size = 1e6.to_i
      max_cached_prime = @primes.last
      @max_checked = max_cached_prime + 1 if max_cached_prime > @max_checked

      segment_min = @max_checked
      segment_max = [segment_min + max_segment_size, max_cached_prime * 2].min
      root = Integer(Math.sqrt(segment_max).floor)

      sieving_primes = @primes[1 .. -1].take_while { |prime| prime <= root }
      offsets = Array.new(sieving_primes.size) do |i|
        (-(segment_min + 1 + sieving_primes[i]) / 2) % sieving_primes[i]
      end

      segment = ((segment_min + 1) .. segment_max).step(2).to_a
      sieving_primes.each_with_index do |prime, index|
        composite_index = offsets[index]
        while composite_index < segment.size do
          segment[composite_index] = nil
          composite_index += prime
        end
      end

      segment.each do |prime|
        @primes.push prime unless prime.nil?
      end
      @max_checked = segment_max
    end
  end

  module OldCompatibility
    def succ
      @generator.succ
    end
    alias next succ

    def each
      return @generator.dup unless block_given?
      loop do
        yield succ
      end
    end
  end
end
