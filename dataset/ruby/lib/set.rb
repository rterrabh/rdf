

class Set
  include Enumerable

  def self.[](*ary)
    new(ary)
  end

  def initialize(enum = nil, &block) # :yields: o
    @hash ||= Hash.new

    enum.nil? and return

    if block
      do_with_enum(enum) { |o| add(block[o]) }
    else
      merge(enum)
    end
  end

  def do_with_enum(enum, &block) # :nodoc:
    if enum.respond_to?(:each_entry)
      enum.each_entry(&block) if block
    elsif enum.respond_to?(:each)
      enum.each(&block) if block
    else
      raise ArgumentError, "value must be enumerable"
    end
  end
  private :do_with_enum

  def initialize_dup(orig)
    super
    #nodyna <instance_variable_get-1986> <IVG TRIVIAL (public variable)>
    @hash = orig.instance_variable_get(:@hash).dup
  end

  def initialize_clone(orig)
    super
    #nodyna <instance_variable_get-1987> <IVG TRIVIAL (public variable)>
    @hash = orig.instance_variable_get(:@hash).clone
  end

  def freeze    # :nodoc:
    @hash.freeze
    super
  end

  def taint     # :nodoc:
    @hash.taint
    super
  end

  def untaint   # :nodoc:
    @hash.untaint
    super
  end

  def size
    @hash.size
  end
  alias length size

  def empty?
    @hash.empty?
  end

  def clear
    @hash.clear
    self
  end

  def replace(enum)
    if enum.instance_of?(self.class)
      #nodyna <instance_variable_get-1988> <IVG TRIVIAL (public variable)>
      @hash.replace(enum.instance_variable_get(:@hash))
      self
    else
      do_with_enum(enum)
      clear
      merge(enum)
    end
  end

  def to_a
    @hash.keys
  end

  def to_set(klass = Set, *args, &block)
    return self if instance_of?(Set) && klass == Set && block.nil? && args.empty?
    klass.new(self, *args, &block)
  end

  def flatten_merge(set, seen = Set.new) # :nodoc:
    set.each { |e|
      if e.is_a?(Set)
        if seen.include?(e_id = e.object_id)
          raise ArgumentError, "tried to flatten recursive Set"
        end

        seen.add(e_id)
        flatten_merge(e, seen)
        seen.delete(e_id)
      else
        add(e)
      end
    }

    self
  end
  protected :flatten_merge

  def flatten
    self.class.new.flatten_merge(self)
  end

  def flatten!
    if detect { |e| e.is_a?(Set) }
      replace(flatten())
    else
      nil
    end
  end

  def include?(o)
    @hash.include?(o)
  end
  alias member? include?

  def superset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if size < set.size
    set.all? { |o| include?(o) }
  end
  alias >= superset?

  def proper_superset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if size <= set.size
    set.all? { |o| include?(o) }
  end
  alias > proper_superset?

  def subset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if set.size < size
    all? { |o| set.include?(o) }
  end
  alias <= subset?

  def proper_subset?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    return false if set.size <= size
    all? { |o| set.include?(o) }
  end
  alias < proper_subset?

  def intersect?(set)
    set.is_a?(Set) or raise ArgumentError, "value must be a set"
    if size < set.size
      any? { |o| set.include?(o) }
    else
      set.any? { |o| include?(o) }
    end
  end


  def disjoint?(set)
    !intersect?(set)
  end

  def each(&block)
    block or return enum_for(__method__)
    @hash.each_key(&block)
    self
  end

  def add(o)
    @hash[o] = true
    self
  end
  alias << add

  def add?(o)
    if include?(o)
      nil
    else
      add(o)
    end
  end

  def delete(o)
    @hash.delete(o)
    self
  end

  def delete?(o)
    if include?(o)
      delete(o)
    else
      nil
    end
  end

  def delete_if
    block_given? or return enum_for(__method__)
    select { |o| yield o }.each { |o| @hash.delete(o) }
    self
  end

  def keep_if
    block_given? or return enum_for(__method__)
    reject { |o| yield o }.each { |o| @hash.delete(o) }
    self
  end

  def collect!
    block_given? or return enum_for(__method__)
    set = self.class.new
    each { |o| set << yield(o) }
    replace(set)
  end
  alias map! collect!

  def reject!(&block)
    block or return enum_for(__method__)
    n = size
    delete_if(&block)
    size == n ? nil : self
  end

  def select!(&block)
    block or return enum_for(__method__)
    n = size
    keep_if(&block)
    size == n ? nil : self
  end

  def merge(enum)
    if enum.instance_of?(self.class)
      #nodyna <instance_variable_get-1989> <IVG TRIVIAL (public variable)>
      @hash.update(enum.instance_variable_get(:@hash))
    else
      do_with_enum(enum) { |o| add(o) }
    end

    self
  end

  def subtract(enum)
    do_with_enum(enum) { |o| delete(o) }
    self
  end

  def |(enum)
    dup.merge(enum)
  end
  alias + |             ##
  alias union |         ##

  def -(enum)
    dup.subtract(enum)
  end
  alias difference -    ##

  def &(enum)
    n = self.class.new
    do_with_enum(enum) { |o| n.add(o) if include?(o) }
    n
  end
  alias intersection &  ##

  def ^(enum)
    n = Set.new(enum)
    each { |o| if n.include?(o) then n.delete(o) else n.add(o) end }
    n
  end

  def ==(other)
    if self.equal?(other)
      true
    elsif other.instance_of?(self.class)
      #nodyna <instance_variable_get-1990> <IVG TRIVIAL (public variable)>
      @hash == other.instance_variable_get(:@hash)
    elsif other.is_a?(Set) && self.size == other.size
      other.all? { |o| @hash.include?(o) }
    else
      false
    end
  end

  def hash      # :nodoc:
    @hash.hash
  end

  def eql?(o)   # :nodoc:
    return false unless o.is_a?(Set)
    #nodyna <instance_variable_get-1991> <IVG TRIVIAL (public variable)>
    @hash.eql?(o.instance_variable_get(:@hash))
  end

  def classify # :yields: o
    block_given? or return enum_for(__method__)

    h = {}

    each { |i|
      x = yield(i)
      (h[x] ||= self.class.new).add(i)
    }

    h
  end

  def divide(&func)
    func or return enum_for(__method__)

    if func.arity == 2
      require 'tsort'

      class << dig = {}         # :nodoc:
        include TSort

        alias tsort_each_node each_key
        def tsort_each_child(node, &block)
          fetch(node).each(&block)
        end
      end

      each { |u|
        dig[u] = a = []
        each{ |v| func.call(u, v) and a << v }
      }

      set = Set.new()
      dig.each_strongly_connected_component { |css|
        set.add(self.class.new(css))
      }
      set
    else
      Set.new(classify(&func).values)
    end
  end

  InspectKey = :__inspect_key__         # :nodoc:

  def inspect
    ids = (Thread.current[InspectKey] ||= [])

    if ids.include?(object_id)
      return sprintf('#<%s: {...}>', self.class.name)
    end

    begin
      ids << object_id
      return sprintf('#<%s: {%s}>', self.class, to_a.inspect[1..-2])
    ensure
      ids.pop
    end
  end

  def pretty_print(pp)  # :nodoc:
    pp.text sprintf('#<%s: {', self.class.name)
    pp.nest(1) {
      pp.seplist(self) { |o|
        pp.pp o
      }
    }
    pp.text "}>"
  end

  def pretty_print_cycle(pp)    # :nodoc:
    pp.text sprintf('#<%s: {%s}>', self.class.name, empty? ? '' : '...')
  end
end

class SortedSet < Set
  @@setup = false

  class << self
    def [](*ary)        # :nodoc:
      new(ary)
    end

    def setup   # :nodoc:
      @@setup and return

      #nodyna <module_eval-1992> <ME MODERATE (block execution)>
      module_eval {
        alias old_init initialize
      }
      begin
        require 'rbtree'

        #nodyna <module_eval-1993> <ME COMPLEX (define methods)>
        module_eval <<-END, __FILE__, __LINE__+1
          def initialize(*args)
            @hash = RBTree.new
            super
          end

          def add(o)
            o.respond_to?(:<=>) or raise ArgumentError, "value must respond to <=>"
            super
          end
          alias << add
        END
      rescue LoadError
        #nodyna <module_eval-1994> <ME COMPLEX (define methods)>
        module_eval <<-END, __FILE__, __LINE__+1
          def initialize(*args)
            @keys = nil
            super
          end

          def clear
            @keys = nil
            super
          end

          def replace(enum)
            @keys = nil
            super
          end

          def add(o)
            o.respond_to?(:<=>) or raise ArgumentError, "value must respond to <=>"
            @keys = nil
            super
          end
          alias << add

          def delete(o)
            @keys = nil
            @hash.delete(o)
            self
          end

          def delete_if
            block_given? or return enum_for(__method__)
            n = @hash.size
            super
            @keys = nil if @hash.size != n
            self
          end

          def keep_if
            block_given? or return enum_for(__method__)
            n = @hash.size
            super
            @keys = nil if @hash.size != n
            self
          end

          def merge(enum)
            @keys = nil
            super
          end

          def each(&block)
            block or return enum_for(__method__)
            to_a.each(&block)
            self
          end

          def to_a
            (@keys = @hash.keys).sort! unless @keys
            @keys
          end
        END
      end
      #nodyna <module_eval-1995> <ME MODERATE (block execution)>
      module_eval {
        remove_method :old_init
      }

      @@setup = true
    end
  end

  def initialize(*args, &block) # :nodoc:
    SortedSet.setup
    initialize(*args, &block)
  end
end

module Enumerable
  def to_set(klass = Set, *args, &block)
    klass.new(self, *args, &block)
  end
end


