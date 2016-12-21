require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/deprecation'


class Class
  def superclass_delegating_accessor(name, options = {})
    # Create private _name and _name= methods that can still be used if the public
    # methods are overridden.
    _superclass_delegating_accessor("_#{name}", options)

    # Generate the public methods name, name=, and name?.
    # These methods dispatch to the private _name, and _name= methods, making them
    # overridable.
    #nodyna <ID:send-240> <send VERY HIGH ex4>
    #nodyna <ID:send-241> <send VERY HIGH ex3>
    #nodyna <ID:define_method-49> <define_method VERY HIGH ex2>
    singleton_class.send(:define_method, name) { send("_#{name}") }
    #nodyna <ID:send-242> <send VERY HIGH ex4>
    #nodyna <ID:send-243> <send VERY HIGH ex3>
    #nodyna <ID:define_method-50> <define_method VERY HIGH ex2>
    singleton_class.send(:define_method, "#{name}?") { !!send("_#{name}") }
    #nodyna <ID:send-244> <send VERY HIGH ex4>
    #nodyna <ID:send-245> <send VERY HIGH ex2>
    #nodyna <ID:define_method-51> <define_method VERY HIGH ex2>
    singleton_class.send(:define_method, "#{name}=") { |value| send("_#{name}=", value) }

    # If an instance_reader is needed, generate public instance methods name and name?.
    if options[:instance_reader] != false
      #nodyna <ID:send-246> <send VERY HIGH ex3>
      #nodyna <ID:define_method-52> <define_method VERY HIGH ex2>
      define_method(name) { send("_#{name}") }
      #nodyna <ID:send-247> <send VERY HIGH ex3>
      #nodyna <ID:define_method-53> <define_method VERY HIGH ex2>
      define_method("#{name}?") { !!send("#{name}") }
    end
  end

  deprecate superclass_delegating_accessor: :class_attribute

  private
    # Take the object being set and store it in a method. This gives us automatic
    # inheritance behavior, without having to store the object in an instance
    # variable and look up the superclass chain manually.
    def _stash_object_in_method(object, method, instance_reader = true)
      singleton_class.remove_possible_method(method)
      #nodyna <ID:send-248> <send VERY HIGH ex4>
      #nodyna <ID:define_method-54> <define_method VERY HIGH ex2>
      singleton_class.send(:define_method, method) { object }
      remove_possible_method(method)
      #nodyna <ID:define_method-55> <define_method VERY HIGH ex2>
      define_method(method) { object } if instance_reader
    end

    def _superclass_delegating_accessor(name, options = {})
      #nodyna <ID:send-249> <send VERY HIGH ex4>
      #nodyna <ID:define_method-56> <define_method VERY HIGH ex2>
      singleton_class.send(:define_method, "#{name}=") do |value|
        _stash_object_in_method(value, name, options[:instance_reader] != false)
      end
      #nodyna <ID:send-250> <send VERY HIGH ex3>
      send("#{name}=", nil)
    end
end