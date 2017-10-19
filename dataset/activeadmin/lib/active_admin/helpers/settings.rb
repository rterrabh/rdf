module ActiveAdmin

  module Settings

    def self.included(base)
      base.extend ClassMethods
    end

    def read_default_setting(name)
      default_settings[name]
    end

    private

    def default_settings
      self.class.default_settings
    end

    module ClassMethods

      def setting(name, default)
        default_settings[name] = default
        attr_writer name

        #nodyna <define_method-86> <DM COMPLEX (events)>
        define_method name do
          if instance_variable_defined? "@#{name}"
            #nodyna <instance_variable_get-87> <IVG COMPLEX (change-prone variable)>
            instance_variable_get "@#{name}"
          else
            read_default_setting name.to_sym
          end
        end

        #nodyna <define_method-88> <DM COMPLEX (events)>
        define_method "#{name}?" do
          #nodyna <send-89> <SD COMPLEX (change-prone variables)>
          value = public_send(name)
          if value.is_a? Array
            value.any?
          else
            value.present?
          end
        end
      end

      def deprecated_setting(name, default, message = nil)
        setting(name, default)

        message ||= "The #{name} setting is deprecated and will be removed."
        ActiveAdmin::Deprecation.deprecate self,     name,    message
        ActiveAdmin::Deprecation.deprecate self, :"#{name}=", message
      end

      def default_settings
        @default_settings ||= {}
      end

    end


    module Inheritance

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        def settings_inherited_by(heir)
          (@setting_heirs ||= []) << heir
          #nodyna <send-90> <SD TRIVIAL (public methods)>
          heir.send :include, ActiveAdmin::Settings
        end

        def inheritable_setting(name, default)
          setting name, default
          @setting_heirs.each{ |c| c.setting name, default }
        end

        def deprecated_inheritable_setting(name, default)
          deprecated_setting name, default
          @setting_heirs.each{ |c| c.deprecated_setting name, default }
        end

      end
    end

  end
end
