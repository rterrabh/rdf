require 'fileutils'
require 'json'
require 'pathname'
require 'set'
require 'thread'

require "checkpoint"
require 'log4r'

require 'vagrant/util/file_mode'
require 'vagrant/util/platform'
require "vagrant/vagrantfile"
require "vagrant/version"

module Vagrant
  class Environment
    CURRENT_SETUP_VERSION = "1.5"

    DEFAULT_LOCAL_DATA = ".vagrant"

    attr_reader :cwd

    attr_reader :data_dir

    attr_reader :vagrantfile_name

    attr_reader :ui

    attr_reader :ui_class

    attr_reader :home_path

    attr_reader :local_data_path

    attr_reader :tmp_path

    attr_reader :boxes_path

    attr_reader :gems_path

    attr_reader :default_private_key_path

    def initialize(opts=nil)
      opts = {
        cwd:              nil,
        home_path:        nil,
        local_data_path:  nil,
        ui_class:         nil,
        vagrantfile_name: nil,
      }.merge(opts || {})

      opts[:cwd] ||= ENV["VAGRANT_CWD"] if ENV.key?("VAGRANT_CWD")
      opts[:cwd] ||= Dir.pwd
      opts[:cwd] = Pathname.new(opts[:cwd])
      if !opts[:cwd].directory?
        raise Errors::EnvironmentNonExistentCWD, cwd: opts[:cwd].to_s
      end
      opts[:cwd] = opts[:cwd].expand_path

      opts[:ui_class] ||= UI::Silent

      opts[:vagrantfile_name] ||= ENV["VAGRANT_VAGRANTFILE"] if \
        ENV.key?("VAGRANT_VAGRANTFILE")
      opts[:vagrantfile_name] = [opts[:vagrantfile_name]] if \
        opts[:vagrantfile_name] && !opts[:vagrantfile_name].is_a?(Array)

      @cwd              = opts[:cwd]
      @home_path        = opts[:home_path]
      @vagrantfile_name = opts[:vagrantfile_name]
      @ui               = opts[:ui_class].new
      @ui_class         = opts[:ui_class]

      @batch_lock = Mutex.new

      @locks = {}

      @logger = Log4r::Logger.new("vagrant::environment")
      @logger.info("Environment initialized (#{self})")
      @logger.info("  - cwd: #{cwd}")

      @home_path  ||= Vagrant.user_data_path
      @home_path  = Util::Platform.fs_real_path(@home_path)
      @boxes_path = @home_path.join("boxes")
      @data_dir   = @home_path.join("data")
      @gems_path  = @home_path.join("gems")
      @tmp_path   = @home_path.join("tmp")
      @machine_index_dir = @data_dir.join("machine-index")

      setup_home_path

      @checkpoint_thr = Thread.new do
        Thread.current[:result] = nil

        if ENV["VAGRANT_CHECKPOINT_DISABLE"].to_s != ""
          @logger.info("checkpoint: disabled from env var")
          next
        end

        signature_file = @data_dir.join("checkpoint_signature")
        if ENV["VAGRANT_CHECKPOINT_NO_STATE"].to_s != ""
          @logger.info("checkpoint: will not store state")
          signature_file = nil
        end

        Thread.current[:result] = Checkpoint.check(
          product: "vagrant",
          version: VERSION,
          signature_file: signature_file,
          cache_file: @data_dir.join("checkpoint_cache"),
        )
      end

      opts[:local_data_path] ||= ENV["VAGRANT_DOTFILE_PATH"]
      opts[:local_data_path] ||= root_path.join(DEFAULT_LOCAL_DATA) if !root_path.nil?
      if opts[:local_data_path]
        @local_data_path = Pathname.new(File.expand_path(opts[:local_data_path], @cwd))
      end

      if root_path
        plugins_file = root_path.join(".vagrantplugins")
        if plugins_file.file?
          @logger.info("Loading plugins file: #{plugins_file}")
          load plugins_file
        end
      end

      setup_local_data_path

      @default_private_key_path = @home_path.join("insecure_private_key")
      copy_insecure_private_key

      hook(:environment_plugins_loaded, runner: Action::Runner.new(env: self))

      hook(:environment_load, runner: Action::Runner.new(env: self))
    end

    def inspect
      "#<#{self.class}: #{@cwd}>".encode('external')
    end

    def action_runner
      @action_runner ||= Action::Runner.new do
        {
          action_runner:  action_runner,
          box_collection: boxes,
          hook:           method(:hook),
          host:           host,
          machine_index:  machine_index,
          gems_path:      gems_path,
          home_path:      home_path,
          root_path:      root_path,
          tmp_path:       tmp_path,
          ui:             @ui
        }
      end
    end

    def active_machines
      return [] if !@local_data_path

      machine_folder = @local_data_path.join("machines")

      return [] if !machine_folder.directory?

      result = []

      machine_folder.children(true).each do |name_folder|
        next if !name_folder.directory?

        name = name_folder.basename.to_s.to_sym
        name_folder.children(true).each do |provider_folder|
          next if !provider_folder.directory?

          next if !provider_folder.join("id").file?

          provider = provider_folder.basename.to_s.to_sym
          result << [name, provider]
        end
      end

      result
    end

    def batch(parallel=true)
      parallel = false if ENV["VAGRANT_NO_PARALLEL"]

      @batch_lock.synchronize do
        BatchAction.new(parallel).tap do |b|
          yield b

          b.run
        end
      end
    end

    def checkpoint
      @checkpoint_thr.join
      return @checkpoint_thr[:result]
    end

    def cli(*args)
      CLI.new(args.flatten, self).execute
    end

    def default_provider(**opts)
      opts[:exclude]       = Set.new(opts[:exclude]) if opts[:exclude]
      opts[:force_default] = true if !opts.key?(:force_default)

      default = ENV["VAGRANT_DEFAULT_PROVIDER"]
      default = nil if default == ""
      default = default.to_sym if default

      return default if default && opts[:force_default]

      root_config = vagrantfile.config
      if opts[:machine]
        machine_info = vagrantfile.machine_config(opts[:machine], nil, nil)
        root_config = machine_info[:config]
      end

      config = {}
      root_config.vm.__providers.reverse.each_with_index do |key, idx|
        config[key] = idx
      end

      max_priority = 0
      Vagrant.plugin("2").manager.providers.each do |key, data|
        priority = data[1][:priority]
        max_priority = priority if priority > max_priority
      end

      ordered = []
      Vagrant.plugin("2").manager.providers.each do |key, data|
        impl  = data[0]
        popts = data[1]

        next if opts[:exclude] && opts[:exclude].include?(key)

        if !config.key?(key)
          next if popts.key?(:defaultable) && !popts[:defaultable]
        end

        priority = popts[:priority]
        priority = config[key] + max_priority if config.key?(key)

        ordered << [priority, key, impl, popts]
      end

      ordered = ordered.sort do |a, b|
        next -1 if a[1] == default
        next 1  if b[1] == default

        b[0] <=> a[0]
      end

      ordered.each do |_, key, impl, _|
        return key if impl.usable?(false)
      end

      raise Errors::NoDefaultProvider
    end

    def boxes
      @_boxes ||= BoxCollection.new(
        boxes_path,
        hook: method(:hook),
        temp_dir_root: tmp_path)
    end

    def config_loader
      return @config_loader if @config_loader

      home_vagrantfile = nil
      root_vagrantfile = nil
      home_vagrantfile = find_vagrantfile(home_path) if home_path
      if root_path
        root_vagrantfile = find_vagrantfile(root_path, @vagrantfile_name)
      end

      @config_loader = Config::Loader.new(
        Config::VERSIONS, Config::VERSIONS_ORDER)
      @config_loader.set(:home, home_vagrantfile) if home_vagrantfile
      @config_loader.set(:root, root_vagrantfile) if root_vagrantfile
      @config_loader
    end

    def hook(name, opts=nil)
      @logger.info("Running hook: #{name}")
      opts ||= {}
      opts[:callable] ||= Action::Builder.new
      opts[:runner] ||= action_runner
      opts[:action_name] = name
      opts[:env] = self
      opts.delete(:runner).run(opts.delete(:callable), opts)
    end

    def host
      return @host if defined?(@host)

      host_klass = vagrantfile.config.vagrant.host
      host_klass = nil if host_klass == :detect

      begin
        @host = Host.new(
          host_klass,
          Vagrant.plugin("2").manager.hosts,
          Vagrant.plugin("2").manager.host_capabilities,
          self)
      rescue Errors::CapabilityHostNotDetected
        klass = Class.new(Vagrant.plugin("2", :host)) do
          def detect?(env); true; end
        end

        hosts     = { generic: [klass, nil] }
        host_caps = {}

        @host = Host.new(:generic, hosts, host_caps, self)
      rescue Errors::CapabilityHostExplicitNotDetected => e
        raise Errors::HostExplicitNotDetected, e.extra_data
      end
    end

    def lock(name="global", **opts)
      f = nil

      return if !block_given?

      return yield if @locks[name] || opts[:noop]

      lock_path = data_dir.join("lock.#{name}.lock")

      @logger.debug("Attempting to acquire process-lock: #{name}")
      lock("dotlock", noop: name == "dotlock", retry: true) do
        f = File.open(lock_path, "w+")
      end

      while f.flock(File::LOCK_EX | File::LOCK_NB) === false
        @logger.warn("Process-lock in use: #{name}")

        if !opts[:retry]
          raise Errors::EnvironmentLockedError,
            name: name
        end

        sleep 0.2
      end

      @logger.info("Acquired process lock: #{name}")

      result = nil
      begin
        @locks[name] = true

        result = yield
      ensure
        @locks.delete(name)
        @logger.info("Released process lock: #{name}")
      end

      if name != "dotlock"
        lock("dotlock", retry: true) do
          f.close
          File.delete(lock_path)
        end
      end

      return result
    ensure
      begin
        f.close if f
      rescue IOError
      end
    end

    def push(name)
      @logger.info("Getting push: #{name}")

      name = name.to_sym

      pushes = self.vagrantfile.config.push.__compiled_pushes
      if !pushes.key?(name)
        raise Vagrant::Errors::PushStrategyNotDefined,
          name: name,
          pushes: pushes.keys
      end

      strategy, config = pushes[name]
      push_registry = Vagrant.plugin("2").manager.pushes
      klass, _ = push_registry.get(strategy)
      if klass.nil?
        raise Vagrant::Errors::PushStrategyNotLoaded,
          name: strategy,
          pushes: push_registry.keys
      end

      klass.new(self, config).push
    end

    def pushes
      self.vagrantfile.config.push.__compiled_pushes.keys
    end

    def machine(name, provider, refresh=false)
      @logger.info("Getting machine: #{name} (#{provider})")

      cache_key = [name, provider]
      @machines ||= {}
      if refresh
        @logger.info("Refreshing machine (busting cache): #{name} (#{provider})")
        @machines.delete(cache_key)
      end

      if @machines.key?(cache_key)
        @logger.info("Returning cached machine: #{name} (#{provider})")
        return @machines[cache_key]
      end

      @logger.info("Uncached load of machine.")

      machine_data_path = @local_data_path.join(
        "machines/#{name}/#{provider}")

      @machines[cache_key] = vagrantfile.machine(
        name, provider, boxes, machine_data_path, self)
    end

    def machine_index
      @machine_index ||= MachineIndex.new(@machine_index_dir)
    end

    def machine_names
      vagrantfile.machine_names
    end

    def primary_machine_name
      vagrantfile.primary_machine_name
    end

    def root_path
      return @root_path if defined?(@root_path)

      root_finder = lambda do |path|
        vf = find_vagrantfile(path, @vagrantfile_name)
        return path if vf
        return nil if path.root? || !File.exist?(path)
        root_finder.call(path.parent)
      end

      @root_path = root_finder.call(cwd)
    end

    def unload
      hook(:environment_unload)
    end

    def vagrantfile
      @vagrantfile ||= Vagrantfile.new(config_loader, [:home, :root])
    end


    def setup_home_path
      @logger.info("Home path: #{@home_path}")

      dirs    = [
        @home_path,
        @home_path.join("rgloader"),
        @boxes_path,
        @data_dir,
        @gems_path,
        @tmp_path,
        @machine_index_dir,
      ]

      dirs.each do |dir|
        next if File.directory?(dir)

        begin
          @logger.info("Creating: #{dir}")
          FileUtils.mkdir_p(dir)
        rescue Errno::EACCES
          raise Errors::HomeDirectoryNotAccessible, home_path: @home_path.to_s
        end
      end

      begin
        suffix = (0...32).map { (65 + rand(26)).chr }.join
        path   = @home_path.join("perm_test_#{suffix}")
        path.open("w") do |f|
          f.write("hello")
        end
        path.unlink
      rescue Errno::EACCES
        raise Errors::HomeDirectoryNotAccessible, home_path: @home_path.to_s
      end

      version_file = @home_path.join("setup_version")
      if version_file.file?
        version = version_file.read.chomp
        if version > CURRENT_SETUP_VERSION
          raise Errors::HomeDirectoryLaterVersion
        end

        case version
        when CURRENT_SETUP_VERSION
        when "1.1"
          upgrade_home_path_v1_1

          version_file.delete
        else
          raise Errors::HomeDirectoryUnknownVersion,
            path: @home_path.to_s,
            version: version
        end
      end

      if !version_file.file?
        @logger.debug(
          "Creating home directory version file: #{CURRENT_SETUP_VERSION}")
        version_file.open("w") do |f|
          f.write(CURRENT_SETUP_VERSION)
        end
      end

      loader_file = @home_path.join("rgloader", "loader.rb")
      if !loader_file.file?
        source_loader = Vagrant.source_root.join("templates/rgloader.rb")
        FileUtils.cp(source_loader.to_s, loader_file.to_s)
      end
    end

    def setup_local_data_path
      if @local_data_path.nil?
        @logger.warn("No local data path is set. Local data cannot be stored.")
        return
      end

      @logger.info("Local data path: #{@local_data_path}")

      if @local_data_path.file?
        upgrade_v1_dotfile(@local_data_path)
      end

      begin
        @logger.debug("Creating: #{@local_data_path}")
        FileUtils.mkdir_p(@local_data_path)
      rescue Errno::EACCES
        raise Errors::LocalDataDirectoryNotAccessible,
          local_data_path: @local_data_path.to_s
      end
    end

    protected

    def copy_insecure_private_key
      if !@default_private_key_path.exist?
        @logger.info("Copying private key to home directory")

        source      = File.expand_path("keys/vagrant", Vagrant.source_root)
        destination = @default_private_key_path

        begin
          FileUtils.cp(source, destination)
        rescue Errno::EACCES
          raise Errors::CopyPrivateKeyFailed,
            source: source,
            destination: destination
        end
      end

      if !Util::Platform.windows?
        if Util::FileMode.from_octal(@default_private_key_path.stat.mode) != "600"
          @logger.info("Changing permissions on private key to 0600")
          @default_private_key_path.chmod(0600)
        end
      end
    end

    def find_vagrantfile(search_path, filenames=nil)
      filenames ||= ["Vagrantfile", "vagrantfile"]
      filenames.each do |vagrantfile|
        current_path = search_path.join(vagrantfile)
        return current_path if current_path.file?
      end

      nil
    end

    def upgrade_home_path_v1_1
      if !ENV["VAGRANT_UPGRADE_SILENT_1_5"]
        @ui.ask(I18n.t("vagrant.upgrading_home_path_v1_5"))
      end

      collection = BoxCollection.new(
        @home_path.join("boxes"), temp_dir_root: tmp_path)
      collection.upgrade_v1_1_v1_5
    end

    def upgrade_v1_dotfile(path)
      @logger.info("Upgrading V1 dotfile to V2 directory structure...")

      contents = path.read.strip
      if contents.strip == ""
        @logger.info("V1 dotfile was empty. Removing and moving on.")
        path.delete
        return
      end

      @logger.debug("Attempting to parse JSON of V1 file")
      json_data = nil
      begin
        json_data = JSON.parse(contents)
        @logger.debug("JSON parsed successfully. Things are okay.")
      rescue JSON::ParserError
        raise Errors::DotfileUpgradeJSONError,
          state_file: path.to_s
      end

      backup_file = path.dirname.join(".vagrant.v1.#{Time.now.to_i}")
      @logger.info("Renaming old dotfile to: #{backup_file}")
      path.rename(backup_file)

      setup_local_data_path

      if json_data["active"]
        @logger.debug("Upgrading to V2 style for each active VM")
        json_data["active"].each do |name, id|
          @logger.info("Upgrading dotfile: #{name} (#{id})")

          directory = @local_data_path.join("machines/#{name}/virtualbox")
          FileUtils.mkdir_p(directory)

          directory.join("id").open("w+") do |f|
            f.write(id)
          end
        end
      end

      @ui.info(I18n.t("vagrant.general.upgraded_v1_dotfile",
                      backup_path: backup_file.to_s))
    end
  end
end
