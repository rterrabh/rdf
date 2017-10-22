module Vagrant
  module Plugin
    module V1
      class Config
        UNSET_VALUE = Object.new

        def finalize!
        end

        def merge(other)
          result = self.class.new

          [self, other].each do |obj|
            obj.instance_variables.each do |key|
              if !key.to_s.start_with?("@__")
                #nodyna <instance_variable_get-3072> <IVG MODERATE (change-prone variable)>
                #nodyna <instance_variable_set-3073> <IVS MODERATE (change-prone variable)>
                result.instance_variable_set(key, obj.instance_variable_get(key))
              end
            end
          end

          result
        end

        def set_options(options)
          options.each do |key, value|
            #nodyna <send-3074> <SD COMPLEX (change-prone variables)>
            send("#{key}=", value)
          end
        end

        def to_json(*a)
          instance_variables_hash.to_json(*a)
        end

        def instance_variables_hash
          instance_variables.inject({}) do |acc, iv|
            #nodyna <instance_variable_get-3075> <IVG COMPLEX (change-prone variable)>
            acc[iv.to_s[1..-1]] = instance_variable_get(iv)
            acc
          end
        end

        def upgrade(new)
        end

        def validate(env, errors)
        end
      end
    end
  end
end
