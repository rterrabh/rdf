begin
  require 'thor/group'
rescue LoadError
  puts "Thor is not available.\nIf you ran this command from a git checkout " \
       "of Rails, please make sure thor is installed,\nand run this command " \
       "as `ruby #{$0} #{(ARGV | ['--dev']).join(" ")}`"
  exit
end

module Rails
  module Generators
    class Error < Thor::Error # :nodoc:
    end

    class Base < Thor::Group
      include Thor::Actions
      include Rails::Generators::Actions

      add_runtime_options!
      strict_args_position!

      def self.source_root(path=nil)
        @_source_root = path if path
        @_source_root ||= default_source_root
      end

      def self.desc(description=nil)
        return super if description

        @desc ||= if usage_path
          ERB.new(File.read(usage_path)).result(binding)
        else
          "Description:\n    Create #{base_name.humanize.downcase} files for #{generator_name} generator."
        end
      end

      def self.namespace(name=nil)
        return super if name
        @namespace ||= super.sub(/_generator$/, '').sub(/:generators:/, ':')
      end

      def self.hide!
        Rails::Generators.hide_namespace self.namespace
      end

      def self.hook_for(*names, &block)
        options = names.extract_options!
        in_base = options.delete(:in) || base_name
        as_hook = options.delete(:as) || generator_name

        names.each do |name|
          unless class_options.key?(name)
            defaults = if options[:type] == :boolean
              { }
            elsif [true, false].include?(default_value_for_option(name, options))
              { banner: "" }
            else
              { desc: "#{name.to_s.humanize} to be invoked", banner: "NAME" }
            end

            class_option(name, defaults.merge!(options))
          end

          hooks[name] = [ in_base, as_hook ]
          invoke_from_option(name, options, &block)
        end
      end

      def self.remove_hook_for(*names)
        remove_invocation(*names)

        names.each do |name|
          hooks.delete(name)
        end
      end

      def self.class_option(name, options={}) #:nodoc:
        options[:desc]    = "Indicates when to generate #{name.to_s.humanize.downcase}" unless options.key?(:desc)
        options[:aliases] = default_aliases_for_option(name, options)
        options[:default] = default_value_for_option(name, options)
        super(name, options)
      end

      def self.default_source_root
        return unless base_name && generator_name
        return unless default_generator_root
        path = File.join(default_generator_root, 'templates')
        path if File.exist?(path)
      end

      def self.base_root
        File.dirname(__FILE__)
      end

      def self.inherited(base) #:nodoc:
        super

        base.source_root

        if base.name && base.name !~ /Base$/
          Rails::Generators.subclasses << base

          Rails::Generators.templates_path.each do |path|
            if base.name.include?('::')
              base.source_paths << File.join(path, base.base_name, base.generator_name)
            else
              base.source_paths << File.join(path, base.generator_name)
            end
          end
        end
      end

      protected

        def class_collisions(*class_names) #:nodoc:
          return unless behavior == :invoke

          class_names.flatten.each do |class_name|
            class_name = class_name.to_s
            next if class_name.strip.empty?

            nesting = class_name.split('::')
            last_name = nesting.pop
            last = extract_last_module(nesting)

            if last && last.const_defined?(last_name.camelize, false)
              raise Error, "The name '#{class_name}' is either already used in your application " <<
                           "or reserved by Ruby on Rails. Please choose an alternative and run "  <<
                           "this generator again."
            end
          end
        end

        def extract_last_module(nesting)
          nesting.inject(Object) do |last_module, nest|
            break unless last_module.const_defined?(nest, false)
            #nodyna <const_get-1161> <CG COMPLEX (array)>
            last_module.const_get(nest)
          end
        end

        def self.banner
          "rails generate #{namespace.sub(/^rails:/,'')} #{self.arguments.map{ |a| a.usage }.join(' ')} [options]".gsub(/\s+/, ' ')
        end

        def self.base_name
          @base_name ||= begin
            if base = name.to_s.split('::').first
              base.underscore
            end
          end
        end

        def self.generator_name
          @generator_name ||= begin
            if generator = name.to_s.split('::').last
              generator.sub!(/Generator$/, '')
              generator.underscore
            end
          end
        end

        def self.default_value_for_option(name, options)
          default_for_option(Rails::Generators.options, name, options, options[:default])
        end

        def self.default_aliases_for_option(name, options)
          default_for_option(Rails::Generators.aliases, name, options, options[:aliases])
        end

        def self.default_for_option(config, name, options, default)
          if generator_name and c = config[generator_name.to_sym] and c.key?(name)
            c[name]
          elsif base_name and c = config[base_name.to_sym] and c.key?(name)
            c[name]
          elsif config[:rails].key?(name)
            config[:rails][name]
          else
            default
          end
        end

        def self.hooks #:nodoc:
          @hooks ||= from_superclass(:hooks, {})
        end

        def self.prepare_for_invocation(name, value) #:nodoc:
          return super unless value.is_a?(String) || value.is_a?(Symbol)

          if value && constants = self.hooks[name]
            value = name if TrueClass === value
            Rails::Generators.find_by_namespace(value, *constants)
          elsif klass = Rails::Generators.find_by_namespace(value)
            klass
          else
            super
          end
        end

        def self.add_shebang_option!
          class_option :ruby, type: :string, aliases: "-r", default: Thor::Util.ruby_command,
                              desc: "Path to the Ruby binary of your choice", banner: "PATH"

          no_tasks {
            #nodyna <define_method-1162> <DM MODERATE (events)>
            define_method :shebang do
              @shebang ||= begin
                command = if options[:ruby] == Thor::Util.ruby_command
                  "/usr/bin/env #{File.basename(Thor::Util.ruby_command)}"
                else
                  options[:ruby]
                end
                "#!#{command}"
              end
            end
          }
        end

        def self.usage_path
          paths = [
            source_root && File.expand_path("../USAGE", source_root),
            default_generator_root && File.join(default_generator_root, "USAGE")
          ]
          paths.compact.detect { |path| File.exist? path }
        end

        def self.default_generator_root
          path = File.expand_path(File.join(base_name, generator_name), base_root)
          path if File.exist?(path)
        end

    end
  end
end
