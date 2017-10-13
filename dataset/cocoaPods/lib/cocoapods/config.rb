module Pod
  class Config
    DEFAULTS = {
      :verbose             => false,
      :silent              => false,
      :skip_repo_update    => false,
      :skip_download_cache => !ENV['COCOAPODS_SKIP_CACHE'].nil?,

      :clean               => true,
      :integrate_targets   => true,
      :deduplicate_targets => true,
      :deterministic_uuids => ENV['COCOAPODS_DISABLE_DETERMINISTIC_UUIDS'].nil?,
      :lock_pod_source     => true,
      :new_version_message => ENV['COCOAPODS_SKIP_UPDATE_MESSAGE'].nil?,

      :cache_root          => Pathname.new(Dir.home) + 'Library/Caches/CocoaPods',
    }

    def with_changes(changes)
      old = {}
      changes.keys.each do |key|
        key = key.to_sym
        #nodyna <send-2699> <SD COMPLEX (array)>
        old[key] = send(key) if respond_to?(key)
      end
      configure_with(changes)
      yield if block_given?
    ensure
      configure_with(old)
    end

    public



    attr_accessor :verbose
    alias_method :verbose?, :verbose

    attr_accessor :silent
    alias_method :silent?, :silent

    attr_accessor :new_version_message
    alias_method :new_version_message?, :new_version_message



    attr_accessor :clean
    alias_method :clean?, :clean

    attr_accessor :lock_pod_source
    alias_method :lock_pod_source?, :lock_pod_source

    attr_accessor :integrate_targets
    alias_method :integrate_targets?, :integrate_targets

    attr_accessor :deduplicate_targets
    alias_method :deduplicate_targets?, :deduplicate_targets

    attr_accessor :deterministic_uuids
    alias_method :deterministic_uuids?, :deterministic_uuids

    attr_accessor :skip_repo_update
    alias_method :skip_repo_update?, :skip_repo_update

    attr_accessor :skip_download_cache
    alias_method :skip_download_cache?, :skip_download_cache

    public



    attr_accessor :cache_root

    def cache_root
      @cache_root.mkpath unless @cache_root.exist?
      @cache_root
    end

    public



    def initialize(use_user_settings = true)
      configure_with(DEFAULTS)

      if use_user_settings && user_settings_file.exist?
        require 'yaml'
        user_settings = YAML.load_file(user_settings_file)
        configure_with(user_settings)
      end
    end

    def verbose
      @verbose && !silent
    end

    public



    def home_dir
      @home_dir ||= Pathname.new(ENV['CP_HOME_DIR'] || '~/.cocoapods').expand_path
    end

    def repos_dir
      @repos_dir ||= Pathname.new(ENV['CP_REPOS_DIR'] || '~/.cocoapods/repos').expand_path
    end

    attr_writer :repos_dir

    def templates_dir
      @templates_dir ||= Pathname.new(ENV['CP_TEMPLATES_DIR'] || '~/.cocoapods/templates').expand_path
    end

    def installation_root
      current_path = Pathname.pwd
      unless @installation_root
        until current_path.root?
          if podfile_path_in_dir(current_path)
            @installation_root = current_path
            unless current_path == Pathname.pwd
              UI.puts("[in #{current_path}]")
            end
            break
          else
            current_path = current_path.parent
          end
        end
        @installation_root ||= Pathname.pwd
      end
      @installation_root
    end

    attr_writer :installation_root
    alias_method :project_root, :installation_root

    def sandbox_root
      @sandbox_root ||= installation_root + 'Pods'
    end

    attr_writer :sandbox_root
    alias_method :project_pods_root, :sandbox_root

    def sandbox
      @sandbox ||= Sandbox.new(sandbox_root)
    end

    def podfile
      @podfile ||= Podfile.from_file(podfile_path) if podfile_path
    end
    attr_writer :podfile

    def lockfile
      @lockfile ||= Lockfile.from_file(lockfile_path) if lockfile_path
    end

    def podfile_path
      @podfile_path ||= podfile_path_in_dir(installation_root)
    end

    def lockfile_path
      @lockfile_path ||= installation_root + 'Podfile.lock'
    end

    def default_podfile_path
      @default_podfile_path ||= templates_dir + 'Podfile.default'
    end

    def default_test_podfile_path
      @default_test_podfile_path ||= templates_dir + 'Podfile.test'
    end

    def search_index_file
      cache_root + 'search_index.yaml'
    end

    private



    def user_settings_file
      home_dir + 'config.yaml'
    end

    def configure_with(values_by_key)
      return unless values_by_key
      values_by_key.each do |key, value|
        #nodyna <instance_variable_set-2700> <IVS COMPLEX (array)>
        instance_variable_set("@#{key}", value)
      end
    end

    PODFILE_NAMES = [
      'CocoaPods.podfile.yaml',
      'CocoaPods.podfile',
      'Podfile',
    ].freeze

    public

    def podfile_path_in_dir(dir)
      PODFILE_NAMES.each do |filename|
        candidate = dir + filename
        if candidate.exist?
          return candidate
        end
      end
      nil
    end

    public



    def self.instance
      @instance ||= new
    end

    class << self
      attr_writer :instance
    end

    module Mixin
      def config
        Config.instance
      end
    end
  end
end
