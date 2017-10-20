require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/array/extract_options'

class Class
  def class_attribute(*attrs)
    options = attrs.extract_options!
    instance_reader = options.fetch(:instance_accessor, true) && options.fetch(:instance_reader, true)
    instance_writer = options.fetch(:instance_accessor, true) && options.fetch(:instance_writer, true)
    instance_predicate = options.fetch(:instance_predicate, true)

    attrs.each do |name|
      define_singleton_method(name) { nil }
      #nodyna <send-1079> <SD MODERATE (change-prone variables)>
      define_singleton_method("#{name}?") { !!public_send(name) } if instance_predicate

      ivar = "@#{name}"

      define_singleton_method("#{name}=") do |val|
        #nodyna <class_eval-1080> <CE MODERATE (block execution)>
        singleton_class.class_eval do
          remove_possible_method(name)
          #nodyna <define_method-1081> <DM MODERATE (events)>
          define_method(name) { val }
        end

        if singleton_class?
          #nodyna <class_eval-1082> <CE MODERATE (define methods)>
          class_eval do
            remove_possible_method(name)
            #nodyna <define_method-1083> <DM MODERATE (events)>
            define_method(name) do
              if instance_variable_defined? ivar
                #nodyna <instance_variable_get-1084> <IVG MODERATE (change-prone variable)>
                instance_variable_get ivar
              else
                #nodyna <send-1085> <SD MODERATE (change-prone variables)>
                singleton_class.send name
              end
            end
          end
        end
        val
      end

      if instance_reader
        remove_possible_method name
        #nodyna <define_method-1086> <DM MODERATE (events)>
        define_method(name) do
          if instance_variable_defined?(ivar)
            #nodyna <instance_variable_get-1087> <IVG MODERATE (change-prone variable)>
            instance_variable_get ivar
          else
            #nodyna <send-1088> <SD MODERATE (change-prone variables)>
            self.class.public_send name
          end
        end
        #nodyna <send-1089> <SD MODERATE (change-prone variables)>
        #nodyna <define_method-1090> <DM MODERATE (events)>
        define_method("#{name}?") { !!public_send(name) } if instance_predicate
      end

      attr_writer name if instance_writer
    end
  end

  private

    unless respond_to?(:singleton_class?)
      def singleton_class?
        ancestors.first != self
      end
    end
end
