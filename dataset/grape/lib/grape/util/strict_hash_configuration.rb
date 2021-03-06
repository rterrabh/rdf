module Grape
  module Util
    module StrictHashConfiguration
      extend ActiveSupport::Concern

      module DSL
        extend ActiveSupport::Concern

        module ClassMethods
          def settings
            config_context.to_hash
          end

          def configure(&block)
            #nodyna <instance_exec-2830> <IEX COMPLEX (block without parameters)>
            config_context.instance_exec(&block)
          end
        end
      end

      class SettingsContainer
        def initialize
          @settings = {}
          @contexts = {}
        end

        def to_hash
          @settings.to_hash
        end
      end

      def self.config_class(*args)
        new_config_class = Class.new(SettingsContainer)

        args.each do |setting_name|
          if setting_name.respond_to? :values
            nested_settings_methods(setting_name, new_config_class)
          else
            simple_settings_methods(setting_name, new_config_class)
          end
        end

        new_config_class
      end

      def self.simple_settings_methods(setting_name, new_config_class)
        setting_name_sym = setting_name.to_sym
        #nodyna <class_eval-2831> <CE MODERATE (define methods)>
        new_config_class.class_eval do
          #nodyna <define_method-2832> <DM COMPLEX (events)>
          define_method setting_name do |new_value|
            @settings[setting_name_sym] = new_value
          end
        end
      end

      def self.nested_settings_methods(setting_name, new_config_class)
        #nodyna <class_eval-2833> <CE MODERATE (define methods)>
        new_config_class.class_eval do
          setting_name.each_pair do |key, value|
            #nodyna <define_method-2834> <DM COMPLEX (events)>
            define_method "#{key}_context" do
              @contexts[key] ||= Grape::Util::StrictHashConfiguration.config_class(*value).new
            end

            #nodyna <define_method-2835> <DM COMPLEX (events)>
            define_method key do |&block|
              #nodyna <instance_exec-2836> <IEX COMPLEX (block without parameters)>
              #nodyna <send-2837> <SD COMPLEX (change-prone variables)>
              send("#{key}_context").instance_exec(&block)
            end
          end

          #nodyna <define_method-2838> <DM COMPLEX (events)>
          define_method 'to_hash' do
            #nodyna <send-2839> <SD COMPLEX (array)>
            merge_hash = setting_name.keys.each_with_object({}) { |k, hash| hash[k] = send("#{k}_context").to_hash }

            @settings.to_hash.merge(
              merge_hash
            )
          end
        end
      end

      def self.module(*args)
        new_module = Module.new do
          extend ActiveSupport::Concern
          include DSL
        end

        new_module.tap do |mod|
          class_mod = create_class_mod(args)

          #nodyna <const_set-2840> <CS TRIVIAL (static values)>
          mod.const_set(:ClassMethods, class_mod)
        end
      end

      def self.create_class_mod(args)
        new_module = Module.new do
          def config_context
            @config_context ||= config_class.new
          end
        end

        new_module.tap do |class_mod|
          new_config_class = config_class(*args)

          #nodyna <define_method-2841> <DM COMPLEX (events)>
          #nodyna <send-2842> <SD COMPLEX (private methods)>
          class_mod.send(:define_method, :config_class) do
            @config_context ||= new_config_class
          end
        end
      end
    end
  end
end
