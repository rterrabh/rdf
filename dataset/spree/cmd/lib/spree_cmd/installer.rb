require 'rbconfig'
require 'active_support/core_ext/string'

module SpreeCmd

  class Installer < Thor::Group
    include Thor::Actions

    desc 'Creates a new rails project with a spree store'
    argument :app_path, :type => :string, :desc => 'rails app_path', :default => '.'

    class_option :auto_accept, :type => :boolean, :aliases => '-A',
                               :desc => 'Answer yes to all prompts'

    class_option :skip_install_data, :type => :boolean, :default => false,
                 :desc => 'Skip running migrations and loading seed and sample data'

    class_option :version, :type => :string, :desc => 'Spree Version to use'

    class_option :edge, :type => :boolean

    class_option :path, :type => :string, :desc => 'Spree gem path'
    class_option :git, :type => :string, :desc => 'Spree gem git url'
    class_option :ref, :type => :string, :desc => 'Spree gem git ref'
    class_option :branch, :type => :string, :desc => 'Spree gem git branch'
    class_option :tag, :type => :string, :desc => 'Spree gem git tag'

    def verify_rails
      unless rails_project?
        say "#{@app_path} is not a rails project."
        exit 1
      end
    end

    def verify_image_magick
      unless image_magick_installed?
        say "Image magick must be installed."
        exit 1
      end
    end

    def prepare_options
      @spree_gem_options = {}

      if options[:edge] || options[:branch]
        @spree_gem_options[:git] = 'https://github.com/spree/spree.git'
      elsif options[:path]
        @spree_gem_options[:path] = options[:path]
      elsif options[:git]
        @spree_gem_options[:git] = options[:git]
        @spree_gem_options[:ref] = options[:ref] if options[:ref]
        @spree_gem_options[:tag] = options[:tag] if options[:tag]
      elsif options[:version]
        @spree_gem_options[:version] = options[:version]
      else
        version = Gem.loaded_specs['spree_cmd'].version
        @spree_gem_options[:version] = version.to_s
      end

      @spree_gem_options[:branch] = options[:branch] if options[:branch]
    end

    def ask_questions
      @install_default_gateways = ask_with_default('Would you like to install the default gateways? (Recommended)')
      @install_default_auth = ask_with_default('Would you like to install the default authentication system?')

      if @install_default_auth
        @user_class = "Spree::User"
      else
        @user_class = ask("What is the name of the class representing users within your application? [User]")
        if @user_class.blank?
          @user_class = "User"
        end
      end

      if options[:skip_install_data]
        @run_migrations = false
        @load_seed_data = false
        @load_sample_data = false
      else
        @run_migrations = ask_with_default('Would you like to run the migrations?')
        if @run_migrations
          @load_seed_data = ask_with_default('Would you like to load the seed data?')
          @load_sample_data = ask_with_default('Would you like to load the sample data?')
        else
          @load_seed_data = false
          @load_sample_data = false
        end
      end
    end

    def add_gems
      inside @app_path do

        gem :spree, @spree_gem_options

        if @install_default_gateways && @spree_gem_options[:branch]
          gem :spree_gateway, github: 'spree/spree_gateway', branch: @spree_gem_options[:branch]
        elsif @install_default_gateways
          gem :spree_gateway, github: 'spree/spree_gateway', branch: '3-0-stable'
        end

        if @install_default_auth && @spree_gem_options[:branch]
          gem :spree_auth_devise, github: 'spree/spree_auth_devise', branch: @spree_gem_options[:branch]
        elsif @install_default_auth
          gem :spree_auth_devise, github: 'spree/spree_auth_devise', branch: '3-0-stable'
        end

        run 'bundle install', :capture => true
      end
    end

    def initialize_spree
      spree_options = []
      spree_options << "--migrate=#{@run_migrations}"
      spree_options << "--seed=#{@load_seed_data}"
      spree_options << "--sample=#{@load_sample_data}"
      spree_options << "--user_class=#{@user_class}"
      spree_options << "--auto_accept" if options[:auto_accept]

      inside @app_path do
        run "rails generate spree:install #{spree_options.join(' ')}", :verbose => false
      end
    end

    private

      def gem(name, gem_options={})
        say_status :gemfile, name
        parts = ["'#{name}'"]
        parts << ["'#{gem_options.delete(:version)}'"] if gem_options[:version]
        gem_options.each { |key, value| parts << "#{key}: '#{value}'" }
        append_file 'Gemfile', "\ngem #{parts.join(', ')}", :verbose => false
      end

      def ask_with_default(message, default = 'yes')
        return true if options[:auto_accept]

        valid = false
        until valid
          response = ask "#{message} (yes/no) [#{default}]"
          response = default if response.empty?
          valid = (response  =~ /\Ay(?:es)?|no?\Z/i)
        end
        response.downcase[0] == ?y
      end

      def ask_string(message, default, valid_regex = /\w/)
        return default if options[:auto_accept]
        valid = false
        until valid
          response = ask "#{message} [#{default}]"
          response = default if response.empty?
          valid = (valid_regex === response)
        end
        response
      end

      def create_rails_app
        say :create, @app_path

        rails_cmd = "rails new #{@app_path} --skip-bundle"
        rails_cmd << " -m #{options[:template]}" if options[:template]
        rails_cmd << " -d #{options[:database]}" if options[:database]
        run(rails_cmd)
      end

      def rails_project?
        File.exists? File.join(@app_path, 'bin', 'rails')
      end

      def linux?
        /linux/i === RbConfig::CONFIG['host_os']
      end

      def mac?
        /darwin/i === RbConfig::CONFIG['host_os']
      end

      def windows?
        %r{msdos|mswin|djgpp|mingw} === RbConfig::CONFIG['host_os']
      end

      def image_magick_installed?
        cmd = 'identify -version'
        if RUBY_PLATFORM =~ /mingw|mswin/ #windows
          cmd += " >nul"
        else
          cmd += " >/dev/null"
        end
        # true if command executed succesfully
        # false for non zero exit status
        # nil if command execution fails
        system(cmd)
      end
  end
end
