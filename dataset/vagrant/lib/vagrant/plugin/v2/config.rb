require "set"

module Vagrant
  module Plugin
    module V2
      class Config
        UNSET_VALUE = Object.new

        def finalize!
        end

        def merge(other)
          result = self.class.new

          [self, other].each do |obj|
            obj.instance_variables.each do |key|
              if !key.to_s.start_with?("@__")
                #nodyna <instance_variable_get-3066> <IVG MODERATE (change-prone variables)>
                value = obj.instance_variable_get(key)
                #nodyna <instance_variable_set-3067> <IVS MODERATE (change-prone variables)>
                result.instance_variable_set(key, value) if value != UNSET_VALUE
              end
            end
          end

          this_invalid  = @__invalid_methods || Set.new
          #nodyna <instance_variable_get-3068> <IVG EASY (private access)>
          other_invalid = other.instance_variable_get(:"@__invalid_methods") || Set.new
          #nodyna <instance_variable_set-3069> <IVS EASY (private access)>
          result.instance_variable_set(:"@__invalid_methods", this_invalid + other_invalid)

          result
        end

        def method_missing(name, *args, &block)
          return super if @__finalized

          name = name.to_s
          name = name[0...-1] if name.end_with?("=")

          @__invalid_methods ||= Set.new
          @__invalid_methods.add(name)

          ::Vagrant::Config::V2::DummyConfig.new
        end

        def set_options(options)
          options.each do |key, value|
            #nodyna <send-3070> <SD COMPLEX (change-prone variables)>
            send("#{key}=", value)
          end
        end

        def to_json(*a)
          instance_variables_hash.to_json(*a)
        end

        def to_s
          self.class.to_s
        end

        def instance_variables_hash
          instance_variables.inject({}) do |acc, iv|
            #nodyna <instance_variable_get-3071> <IVG COMPLEX (change-prone variables)>
            acc[iv.to_s[1..-1]] = instance_variable_get(iv)
            acc
          end
        end

        def validate(machine)
          return { self.to_s => _detected_errors }
        end

        def _detected_errors
          return [] if !@__invalid_methods || @__invalid_methods.empty?
          return [I18n.t("vagrant.config.common.bad_field",
                         fields: @__invalid_methods.to_a.sort.join(", "))]
        end

        def _finalize!
          @__finalized = true
        end
      end
    end
  end
end
