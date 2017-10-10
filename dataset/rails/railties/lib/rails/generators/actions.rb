require 'rbconfig'

module Rails
  module Generators
    module Actions
      def initialize(*) # :nodoc:
        super
        @in_group = nil
        @after_bundle_callbacks = []
      end

      def gem(*args)
        options = args.extract_options!
        name, version = args

        parts, message = [ quote(name) ], name
        if version ||= options.delete(:version)
          parts   << quote(version)
          message << " (#{version})"
        end
        message = options[:git] if options[:git]

        log :gemfile, message

        options.each do |option, value|
          parts << "#{option}: #{quote(value)}"
        end

        in_root do
          str = "gem #{parts.join(", ")}"
          str = "  " + str if @in_group
          str = "\n" + str
          append_file "Gemfile", str, verbose: false
        end
      end

      def gem_group(*names, &block)
        name = names.map(&:inspect).join(", ")
        log :gemfile, "group #{name}"

        in_root do
          append_file "Gemfile", "\ngroup #{name} do", force: true

          @in_group = true
          #nodyna <instance_eval-1166> <IEV COMPLEX (block execution)>
          instance_eval(&block)
          @in_group = false

          append_file "Gemfile", "\nend\n", force: true
        end
      end

      def add_source(source, options={})
        log :source, source

        in_root do
          prepend_file "Gemfile", "source #{quote(source)}\n", verbose: false
        end
      end

      def environment(data=nil, options={})
        sentinel = /class [a-z_:]+ < Rails::Application/i
        env_file_sentinel = /Rails\.application\.configure do/
        data = yield if !data && block_given?

        in_root do
          if options[:env].nil?
            inject_into_file 'config/application.rb', "\n    #{data}", after: sentinel, verbose: false
          else
            Array(options[:env]).each do |env|
              inject_into_file "config/environments/#{env}.rb", "\n  #{data}", after: env_file_sentinel, verbose: false
            end
          end
        end
      end
      alias :application :environment

      def git(commands={})
        if commands.is_a?(Symbol)
          run "git #{commands}"
        else
          commands.each do |cmd, options|
            run "git #{cmd} #{options}"
          end
        end
      end

      def vendor(filename, data=nil, &block)
        log :vendor, filename
        create_file("vendor/#{filename}", data, verbose: false, &block)
      end

      def lib(filename, data=nil, &block)
        log :lib, filename
        create_file("lib/#{filename}", data, verbose: false, &block)
      end

      def rakefile(filename, data=nil, &block)
        log :rakefile, filename
        create_file("lib/tasks/#{filename}", data, verbose: false, &block)
      end

      def initializer(filename, data=nil, &block)
        log :initializer, filename
        create_file("config/initializers/#{filename}", data, verbose: false, &block)
      end

      def generate(what, *args)
        log :generate, what
        argument = args.flat_map {|arg| arg.to_s }.join(" ")

        in_root { run_ruby_script("bin/rails generate #{what} #{argument}", verbose: false) }
      end

      def rake(command, options={})
        log :rake, command
        env  = options[:env] || ENV["RAILS_ENV"] || 'development'
        sudo = options[:sudo] && RbConfig::CONFIG['host_os'] !~ /mswin|mingw/ ? 'sudo ' : ''
        in_root { run("#{sudo}#{extify(:rake)} #{command} RAILS_ENV=#{env}", verbose: false) }
      end

      def capify!
        log :capify, ""
        in_root { run("#{extify(:capify)} .", verbose: false) }
      end

      def route(routing_code)
        log :route, routing_code
        sentinel = /\.routes\.draw do\s*\n/m

        in_root do
          inject_into_file 'config/routes.rb', "  #{routing_code}\n", { after: sentinel, verbose: false, force: true }
        end
      end

      def readme(path)
        log File.read(find_in_source_paths(path))
      end

      def after_bundle(&block)
        @after_bundle_callbacks << block
      end

      protected

        def log(*args)
          if args.size == 1
            say args.first.to_s unless options.quiet?
          else
            args << (self.behavior == :invoke ? :green : :red)
            say_status(*args)
          end
        end

        def extify(name)
          if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
            "#{name}.bat"
          else
            name
          end
        end

        def quote(value)
          return value.inspect unless value.is_a? String

          if value.include?("'")
            value.inspect
          else
            "'#{value}'"
          end
        end
    end
  end
end
