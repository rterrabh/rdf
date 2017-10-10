require_relative "util/ssh"

require "digest/md5"
require "thread"

require "log4r"

module Vagrant
  class Machine
    attr_accessor :box

    attr_accessor :config

    attr_reader :data_dir

    attr_reader :env

    attr_reader :id

    attr_reader :name

    attr_reader :provider

    attr_accessor :provider_config

    attr_reader :provider_name

    attr_reader :provider_options

    attr_reader :ui

    attr_reader :vagrantfile

    def initialize(name, provider_name, provider_cls, provider_config, provider_options, config, data_dir, box, env, vagrantfile, base=false)
      @logger = Log4r::Logger.new("vagrant::machine")
      @logger.info("Initializing machine: #{name}")
      @logger.info("  - Provider: #{provider_cls}")
      @logger.info("  - Box: #{box}")
      @logger.info("  - Data dir: #{data_dir}")

      @box             = box
      @config          = config
      @data_dir        = data_dir
      @env             = env
      @vagrantfile     = vagrantfile
      @guest           = Guest.new(
        self,
        Vagrant.plugin("2").manager.guests,
        Vagrant.plugin("2").manager.guest_capabilities)
      @name            = name
      @provider_config = provider_config
      @provider_name   = provider_name
      @provider_options = provider_options
      @ui              = Vagrant::UI::Prefixed.new(@env.ui, @name)
      @ui_mutex        = Mutex.new

      @id = nil

      if base
        @id = name
      else
        reload
      end

      @index_uuid_file = nil
      @index_uuid_file = @data_dir.join("index_uuid") if @data_dir

      @provider = provider_cls.new(self)
      @provider._initialize(@provider_name, self)

      if @config.vm.communicator == :winrm
        @logger.debug("Eager loading WinRM communicator to avoid GH-3390")
        communicate
      end

      if state.id == MachineState::NOT_CREATED_ID
        self.id = nil
      end
    end

    def action(name, opts=nil)
      @logger.info("Calling action: #{name} on provider #{@provider}")

      opts ||= {}

      lock = true
      lock = opts.delete(:lock) if opts.key?(:lock)

      extra_env = opts.dup

      vf = nil
      vf = @env.vagrantfile_name[0] if @env.vagrantfile_name
      id = Digest::MD5.hexdigest(
        "#{@env.root_path}#{vf}#{@env.local_data_path}#{@name}")

      locker = Proc.new { |*args, &block| block.call }
      locker = @env.method(:lock) if lock && !name.to_s.start_with?("ssh")

      locker.call("machine-action-#{id}") do
        callable = @provider.action(name)

        if callable.nil?
          raise Errors::UnimplementedProviderAction,
            action: name,
            provider: @provider.to_s
        end

        action_raw(name, callable, extra_env)
      end
    rescue Errors::EnvironmentLockedError
      raise Errors::MachineActionLockedError,
        action: name,
        name: @name
    end

    def action_raw(name, callable, extra_env=nil)
      env = {
        action_name: "machine_action_#{name}".to_sym,
        machine: self,
        machine_action: name,
        ui: @ui,
      }.merge(extra_env || {})
      @env.action_runner.run(callable, env)
    end

    def communicate
      if !@communicator
        requested  = @config.vm.communicator
        requested ||= :ssh
        klass = Vagrant.plugin("2").manager.communicators[requested]
        raise Errors::CommunicatorNotFound, comm: requested.to_s if !klass
        @communicator = klass.new(self)
      end

      @communicator
    end

    def guest
      raise Errors::MachineGuestNotReady if !communicate.ready?
      @guest.detect! if !@guest.ready?
      @guest
    end

    def id=(value)
      @logger.info("New machine ID: #{value.inspect}")

      id_file = nil
      if @data_dir
        id_file = @data_dir.join("id")
      end

      if value
        if id_file
          id_file.open("w+") do |f|
            f.write(value)
          end
        end

        if uid_file
          uid_file.open("w+") do |f|
            f.write(Process.uid.to_s)
          end
        end

        if index_uuid.nil?
          entry = MachineIndex::Entry.new
          entry.local_data_path = @env.local_data_path
          entry.name = @name.to_s
          entry.provider = @provider_name.to_s
          entry.state = "preparing"
          entry.vagrantfile_path = @env.root_path
          entry.vagrantfile_name = @env.vagrantfile_name

          if @box
            entry.extra_data["box"] = {
              "name"     => @box.name,
              "provider" => @box.provider.to_s,
              "version"  => @box.version.to_s,
            }
          end

          entry = @env.machine_index.set(entry)
          @env.machine_index.release(entry)

          if @index_uuid_file
            @index_uuid_file.open("w+") do |f|
              f.write(entry.id)
            end
          end
        end
      else
        id_file.delete if id_file && id_file.file?
        uid_file.delete if uid_file && uid_file.file?

        uuid = index_uuid
        if uuid
          entry = @env.machine_index.get(uuid)
          @env.machine_index.delete(entry) if entry
        end

        if @data_dir
          @data_dir.children.each do |child|
            begin
              child.rmtree
            rescue Errno::EACCES
              @logger.info("EACCESS deleting file: #{child}")
            end
          end
        end
      end

      @id = value.nil? ? nil : value.to_s

      @provider.machine_id_changed
    end

    def index_uuid
      return nil if !@index_uuid_file
      return @index_uuid_file.read.chomp if @index_uuid_file.file?
      return nil
    end

    def inspect
      "#<#{self.class}: #{@name} (#{@provider.class})>"
    end

    def reload
      old_id = @id
      @id = nil

      if @data_dir
        id_file = @data_dir.join("id")
        @id = id_file.read.chomp if id_file.file?
      end

      if @id != old_id && @provider
        @provider.machine_id_changed
      end

      @id
    end

    def ssh_info
      info = @provider.ssh_info
      return nil if info.nil?

      info.dup.each do |key, value|
        info.delete(key) if value.nil?
      end

      info[:host] ||= @config.ssh.default.host
      info[:port] ||= @config.ssh.default.port
      info[:private_key_path] ||= @config.ssh.default.private_key_path
      info[:username] ||= @config.ssh.default.username

      info[:host] = @config.ssh.host if @config.ssh.host
      info[:port] = @config.ssh.port if @config.ssh.port
      info[:username] = @config.ssh.username if @config.ssh.username
      info[:password] = @config.ssh.password if @config.ssh.password

      info[:forward_agent] = @config.ssh.forward_agent
      info[:forward_x11]   = @config.ssh.forward_x11

      info[:ssh_command] = @config.ssh.ssh_command if @config.ssh.ssh_command

      info[:proxy_command] = @config.ssh.proxy_command if @config.ssh.proxy_command

      if !info[:private_key_path] && !info[:password]
        if @config.ssh.private_key_path
          info[:private_key_path] = @config.ssh.private_key_path
        else
          info[:private_key_path] = @env.default_private_key_path
        end
      end

      if @data_dir && !@config.ssh.private_key_path
        data_private_key = @data_dir.join("private_key")
        if data_private_key.file?
          info[:private_key_path] = [data_private_key.to_s]
        end
      end

      info[:private_key_path] ||= []
      info[:private_key_path] = Array(info[:private_key_path])

      info[:private_key_path].map! do |path|
        File.expand_path(path, @env.root_path)
      end

      info[:private_key_path].each do |path|
        key_path = Pathname.new(path)
        if key_path.exist?
          Vagrant::Util::SSH.check_key_permissions(key_path)
        end
      end

      info
    end

    def state
      result = @provider.state
      raise Errors::MachineStateInvalid if !result.is_a?(MachineState)

      uuid = index_uuid
      if uuid
        entry = @env.machine_index.get(uuid)
        if entry
          entry.state = result.short_description
          @env.machine_index.set(entry)
          @env.machine_index.release(entry)
        end
      end

      result
    end

    def uid
      path = uid_file
      return nil if !path
      return nil if !path.file?
      return uid_file.read.chomp
    end

    def with_ui(ui)
      @ui_mutex.synchronize do
        begin
          old_ui = @ui
          @ui    = ui
          yield
        ensure
          @ui = old_ui
        end
      end
    end

    protected

    def uid_file
      return nil if !@data_dir
      @data_dir.join("creator_uid")
    end
  end
end
