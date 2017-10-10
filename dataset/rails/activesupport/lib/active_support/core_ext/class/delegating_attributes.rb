require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/deprecation'


class Class
  def superclass_delegating_accessor(name, options = {})
    _superclass_delegating_accessor("_#{name}", options)

    #nodyna <send-1060> <SD COMPLEX (private methods)>
    #nodyna <send-1061> <SD COMPLEX (change-prone variables)>
    #nodyna <define_method-1062> <DM COMPLEX (events)>
    singleton_class.send(:define_method, name) { send("_#{name}") }
    #nodyna <send-1063> <SD COMPLEX (private methods)>
    #nodyna <send-1064> <SD COMPLEX (change-prone variables)>
    #nodyna <define_method-1065> <DM COMPLEX (events)>
    singleton_class.send(:define_method, "#{name}?") { !!send("_#{name}") }
    #nodyna <send-1066> <SD COMPLEX (private methods)>
    #nodyna <send-1067> <SD COMPLEX (array)>
    #nodyna <define_method-1068> <DM COMPLEX (events)>
    singleton_class.send(:define_method, "#{name}=") { |value| send("_#{name}=", value) }

    if options[:instance_reader] != false
      #nodyna <send-1069> <SD COMPLEX (change-prone variables)>
      #nodyna <define_method-1070> <DM COMPLEX (events)>
      define_method(name) { send("_#{name}") }
      #nodyna <send-1071> <SD COMPLEX (change-prone variables)>
      #nodyna <define_method-1072> <DM COMPLEX (events)>
      define_method("#{name}?") { !!send("#{name}") }
    end
  end

  deprecate superclass_delegating_accessor: :class_attribute

  private
    def _stash_object_in_method(object, method, instance_reader = true)
      singleton_class.remove_possible_method(method)
      #nodyna <send-1073> <SD COMPLEX (private methods)>
      #nodyna <define_method-1074> <DM COMPLEX (events)>
      singleton_class.send(:define_method, method) { object }
      remove_possible_method(method)
      #nodyna <define_method-1075> <DM COMPLEX (events)>
      define_method(method) { object } if instance_reader
    end

    def _superclass_delegating_accessor(name, options = {})
      #nodyna <send-1076> <SD COMPLEX (private methods)>
      #nodyna <define_method-1077> <DM COMPLEX (events)>
      singleton_class.send(:define_method, "#{name}=") do |value|
        _stash_object_in_method(value, name, options[:instance_reader] != false)
      end
      #nodyna <send-1078> <SD COMPLEX (change-prone variables)>
      send("#{name}=", nil)
    end
end
