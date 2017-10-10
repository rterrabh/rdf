module Vagrant
  module Action
    module Builtin
      module MixinProvisioners
        def provisioner_instances(env)
          return @_provisioner_instances if @_provisioner_instances

          @_provisioner_types = {}

          @_provisioner_instances = env[:machine].config.vm.provisioners.map do |provisioner|
            klass  = Vagrant.plugin("2").manager.provisioners[provisioner.type]

            next nil if !klass

            result = klass.new(env[:machine], provisioner.config)

            @_provisioner_types[result] = provisioner.type

            options = {
              name: provisioner.name,
              run:  provisioner.run,
            }

            [result, options]
          end

          return @_provisioner_instances.compact
        end

        def provisioner_type_map(env)
          provisioner_instances(env)

          @_provisioner_types
        end
      end
    end
  end
end
