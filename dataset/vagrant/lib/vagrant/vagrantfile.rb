require "vagrant/util/template_renderer"

module Vagrant
  class Vagrantfile
    attr_reader :config

    def initialize(loader, keys)
      @keys   = keys
      @loader = loader
      @config, _ = loader.load(keys)
    end

    def machine(name, provider, boxes, data_path, env)
      results = machine_config(name, provider, boxes)
      box             = results[:box]
      config          = results[:config]
      config_errors   = results[:config_errors]
      config_warnings = results[:config_warnings]
      provider_cls    = results[:provider_cls]
      provider_options = results[:provider_options]

      if !config_warnings.empty? || !config_errors.empty?
        level  = config_errors.empty? ? :warn : :error
        output = Util::TemplateRenderer.render(
          "config/messages",
          warnings: config_warnings,
          errors: config_errors).chomp
        #nodyna <send-3062> <SD MODERATE (change-prone variables)>
        env.ui.send(level, I18n.t("vagrant.general.config_upgrade_messages",
                               name: name,
                               output: output))

        raise Errors::ConfigUpgradeErrors if !config_errors.empty?
      end

      provider_config = config.vm.get_provider_config(provider)

      FileUtils.mkdir_p(data_path)

      return Machine.new(name, provider, provider_cls, provider_config,
        provider_options, config, data_path, box, env, self)
    end

    def machine_config(name, provider, boxes)
      keys = @keys.dup

      sub_machine = @config.vm.defined_vms[name]
      if !sub_machine
        raise Errors::MachineNotFound,
          name: name, provider: provider
      end

      provider_plugin  = nil
      provider_cls     = nil
      provider_options = {}
      box_formats      = nil
      if provider != nil
        provider_plugin  = Vagrant.plugin("2").manager.providers[provider]
        if !provider_plugin
          raise Errors::ProviderNotFound,
            machine: name, provider: provider
        end

        provider_cls     = provider_plugin[0]
        provider_options = provider_plugin[1]
        box_formats      = provider_options[:box_format] || provider

        begin
          provider_cls.usable?(true)
        rescue Errors::VagrantError => e
          raise Errors::ProviderNotUsable,
            machine: name.to_s,
            provider: provider.to_s,
            message: e.to_s
        end
      end

      vm_config_key = "#{object_id}_machine_#{name}"
      @loader.set(vm_config_key, sub_machine.config_procs)
      keys << vm_config_key

      config, config_warnings, config_errors = @loader.load(keys)

      box = nil
      original_box = config.vm.box

      load_box_proc = lambda do
        local_keys = keys.dup

        if config.vm.box && boxes
          box = boxes.find(config.vm.box, box_formats, config.vm.box_version)
          if box
            box_vagrantfile = find_vagrantfile(box.directory)
            if box_vagrantfile
              box_config_key =
                "#{boxes.object_id}_#{box.name}_#{box.provider}".to_sym
              @loader.set(box_config_key, box_vagrantfile)
              local_keys.unshift(box_config_key)
              config, config_warnings, config_errors = @loader.load(local_keys)
            end
          end
        end

        provider_overrides = config.vm.get_provider_overrides(provider)
        if !provider_overrides.empty?
          config_key =
            "#{object_id}_vm_#{name}_#{config.vm.box}_#{provider}".to_sym
          @loader.set(config_key, provider_overrides)
          local_keys << config_key
          config, config_warnings, config_errors = @loader.load(local_keys)
        end

        if original_box != config.vm.box

          original_box = config.vm.box
          load_box_proc.call
        end
      end

      load_box_proc.call

      return {
        box: box,
        provider_cls: provider_cls,
        provider_options: provider_options.dup,
        config: config,
        config_warnings: config_warnings,
        config_errors: config_errors,
      }
    end

    def machine_names
      @config.vm.defined_vm_keys.dup
    end

    def machine_names_and_options
      {}.tap do |r|
        @config.vm.defined_vms.each do |name, subvm|
          r[name] = subvm.options || {}
        end
      end
    end

    def primary_machine_name
      return machine_names.first if machine_names.length == 1

      @config.vm.defined_vms.each do |name, subvm|
        return name if subvm.options[:primary]
      end

      nil
    end

    protected

    def find_vagrantfile(search_path)
      ["Vagrantfile", "vagrantfile"].each do |vagrantfile|
        current_path = search_path.join(vagrantfile)
        return current_path if current_path.file?
      end

      nil
    end
  end
end
