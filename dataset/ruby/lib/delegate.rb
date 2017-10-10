
class Delegator < BasicObject
  kernel = ::Kernel.dup
  #nodyna <class_eval-1958> <not yet classified>
  kernel.class_eval do
    alias __raise__ raise
    [:to_s,:inspect,:=~,:!~,:===,:<=>,:eql?,:hash].each do |m|
      undef_method m
    end
    private_instance_methods.each do |m|
      if /\Ablock_given\?\z|iterator\?\z|\A__.*__\z/ =~ m
        next
      end
      undef_method m
    end
  end
  include kernel

  def self.const_missing(n)
    #nodyna <const_get-1959> <CG COMPLEX (change-prone variable)>
    ::Object.const_get(n)
  end


  def initialize(obj)
    __setobj__(obj)
  end

  def method_missing(m, *args, &block)
    r = true
    target = self.__getobj__ {r = false}
    begin
      if r && target.respond_to?(m)
        target.__send__(m, *args, &block)
      elsif ::Kernel.respond_to?(m, true)
        ::Kernel.instance_method(m).bind(self).(*args, &block)
      else
        super(m, *args, &block)
      end
    ensure
      $@.delete_if {|t| %r"\A#{Regexp.quote(__FILE__)}:(?:#{[__LINE__-7, __LINE__-5, __LINE__-3].join('|')}):"o =~ t} if $@
    end
  end

  def respond_to_missing?(m, include_private)
    r = true
    target = self.__getobj__ {r = false}
    r &&= target.respond_to?(m, include_private)
    if r && include_private && !target.respond_to?(m, false)
      warn "#{caller(3)[0]}: delegator does not forward private method \##{m}"
      return false
    end
    r
  end

  def methods(all=true)
    __getobj__.methods(all) | super
  end

  def public_methods(all=true)
    __getobj__.public_methods(all) | super
  end

  def protected_methods(all=true)
    __getobj__.protected_methods(all) | super
  end


  def ==(obj)
    return true if obj.equal?(self)
    self.__getobj__ == obj
  end

  def !=(obj)
    return false if obj.equal?(self)
    __getobj__ != obj
  end

  def !
    !__getobj__
  end

  def __getobj__
    __raise__ ::NotImplementedError, "need to define `__getobj__'"
  end

  def __setobj__(obj)
    __raise__ ::NotImplementedError, "need to define `__setobj__'"
  end

  def marshal_dump
    ivars = instance_variables.reject {|var| /\A@delegate_/ =~ var}
    [
      :__v2__,
      #nodyna <instance_variable_get-1960> <not yet classified>
      ivars, ivars.map{|var| instance_variable_get(var)},
      __getobj__
    ]
  end

  def marshal_load(data)
    version, vars, values, obj = data
    if version == :__v2__
      #nodyna <instance_variable_set-1961> <not yet classified>
      vars.each_with_index{|var, i| instance_variable_set(var, values[i])}
      __setobj__(obj)
    else
      __setobj__(data)
    end
  end

  def initialize_clone(obj) # :nodoc:
    self.__setobj__(obj.__getobj__.clone)
  end
  def initialize_dup(obj) # :nodoc:
    self.__setobj__(obj.__getobj__.dup)
  end
  private :initialize_clone, :initialize_dup






  [:trust, :untrust, :taint, :untaint, :freeze].each do |method|
    #nodyna <define_method-1962> <DM MODERATE (array)>
    define_method method do
      #nodyna <send-1963> <SD MODERATE (change-prone variables)>
      __getobj__.send(method)
      super()
    end
  end

  @delegator_api = self.public_instance_methods
  def self.public_api   # :nodoc:
    @delegator_api
  end
end

class SimpleDelegator<Delegator
  def __getobj__
    unless defined?(@delegate_sd_obj)
      return yield if block_given?
      __raise__ ::ArgumentError, "not delegated"
    end
    @delegate_sd_obj
  end

  def __setobj__(obj)
    __raise__ ::ArgumentError, "cannot delegate to self" if self.equal?(obj)
    @delegate_sd_obj = obj
  end
end

def Delegator.delegating_block(mid) # :nodoc:
  lambda do |*args, &block|
    target = self.__getobj__
    begin
      target.__send__(mid, *args, &block)
    ensure
      $@.delete_if {|t| /\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:/o =~ t} if $@
    end
  end
end

def DelegateClass(superclass)
  klass = Class.new(Delegator)
  methods = superclass.instance_methods
  methods -= ::Delegator.public_api
  methods -= [:to_s,:inspect,:=~,:!~,:===]
  #nodyna <module_eval-1964> <not yet classified>
  klass.module_eval do
    def __getobj__  # :nodoc:
      unless defined?(@delegate_dc_obj)
        return yield if block_given?
        __raise__ ::ArgumentError, "not delegated"
      end
      @delegate_dc_obj
    end
    def __setobj__(obj)  # :nodoc:
      __raise__ ::ArgumentError, "cannot delegate to self" if self.equal?(obj)
      @delegate_dc_obj = obj
    end
    methods.each do |method|
      #nodyna <define_method-1965> <DM COMPLEX (array)>
      define_method(method, Delegator.delegating_block(method))
    end
  end
  klass.define_singleton_method :public_instance_methods do |all=true|
    super(all) - superclass.protected_instance_methods
  end
  klass.define_singleton_method :protected_instance_methods do |all=true|
    super(all) | superclass.protected_instance_methods
  end
  return klass
end
