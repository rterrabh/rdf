module ActiveAdmin
  module Callbacks
    extend ActiveSupport::Concern

    private


    def run_callback(method, *args)
      case method
      when Symbol
        #nodyna <send-20> <SD COMPLEX (change-prone variables)>
        send(method, *args)
      when Proc
        #nodyna <instance_exec-21> <IEX COMPLEX (block with parameters)>
        instance_exec(*args, &method)
      else
        raise "Please register with callbacks using a symbol or a block/proc."
      end
    end

    module ClassMethods

      private

      def define_active_admin_callbacks(*names)
        names.each do |name|
          [:before, :after].each do |type|
            callback_name = "#{type}_#{name}_callbacks"
            callback_ivar = "@#{callback_name}"

            #nodyna <send-22> <SD MODERATE (private methods)>
            #nodyna <define_method-23> <DM MODERATE (array)>
            singleton_class.send :define_method, callback_name do
              #nodyna <instance_variable_get-24> <IVG MODERATE (change-prone variable)>
              #nodyna <instance_variable_set-25> <IVS MODERATE (change-prone variable)>
              instance_variable_get(callback_ivar) || instance_variable_set(callback_ivar, [])
            end
            #nodyna <send-26> <SD MODERATE (private methods)>
            singleton_class.send :private, callback_name

            #nodyna <send-27> <SD MODERATE (private methods)>
            #nodyna <define_method-28> <DM MODERATE (array)>
            singleton_class.send :define_method, "#{type}_#{name}" do |method = nil, &block|
              #nodyna <send-29> <SD MODERATE (change-prone variables)>
              send(callback_name).push method || block
            end
          end

          #nodyna <define_method-30> <DM MODERATE (array)>
          define_method "run_#{name}_callbacks" do |*args, &block|
            #nodyna <send-31> <SD MODERATE (change-prone variables)>
            self.class.send("before_#{name}_callbacks").each{ |cbk| run_callback(cbk, *args) }
            value = block.try :call
            #nodyna <send-32> <SD MODERATE (change-prone variables)>
            self.class.send("after_#{name}_callbacks").each { |cbk| run_callback(cbk, *args) }
            return value
          end
          #nodyna <send-33> <SD MODERATE (private methods)>
          send :private, "run_#{name}_callbacks"
        end
      end
    end
  end
end
