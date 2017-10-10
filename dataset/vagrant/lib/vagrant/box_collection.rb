require "digest/sha1"
require "monitor"
require "tmpdir"

require "log4r"

require "vagrant/util/platform"
require "vagrant/util/subprocess"

module Vagrant
  class BoxCollection
    TEMP_PREFIX = "vagrant-box-add-temp-"

    attr_reader :directory

    def initialize(directory, options=nil)
      options ||= {}

      @directory = directory
      @hook      = options[:hook]
      @lock      = Monitor.new
      @temp_root = options[:temp_dir_root]
      @logger    = Log4r::Logger.new("vagrant::box_collection")
    end

    def add(path, name, version, **opts)
      providers = opts[:providers]
      providers = Array(providers) if providers
      provider = nil

      check_box_exists = lambda do |box_formats|
        box = find(name, box_formats, version)
        next if !box

        if !opts[:force]
          @logger.error(
            "Box already exists, can't add: #{name} v#{version} #{box_formats.join(", ")}")
          raise Errors::BoxAlreadyExists,
            name: name,
            provider: box_formats.join(", "),
            version: version
        end

        @logger.info(
          "Box already exists, but forcing so removing: " +
          "#{name} v#{version} #{box_formats.join(", ")}")
        box.destroy!
      end

      with_collection_lock do
        log_provider = providers ? providers.join(", ") : "any provider"
        @logger.debug("Adding box: #{name} (#{log_provider}) from #{path}")

        check_box_exists.call(providers) if providers

        with_temp_dir do |temp_dir|
          @logger.debug("Unpacking box into temporary directory: #{temp_dir}")
          result = Util::Subprocess.execute(
            "bsdtar", "-v", "-x", "-m", "-C", temp_dir.to_s, "-f", path.to_s)
          if result.exit_code != 0
            raise Errors::BoxUnpackageFailure,
              output: result.stderr.to_s
          end

          if v1_box?(temp_dir)
            @logger.debug("Added box is a V1 box. Upgrading in place.")
            temp_dir = v1_upgrade(temp_dir)
          end

          with_temp_dir(temp_dir) do |final_temp_dir|
            box = Box.new(name, nil, version, final_temp_dir)

            box_provider = box.metadata["provider"]

            if providers
              found = providers.find { |p| p.to_sym == box_provider.to_sym }
              if !found
                @logger.error("Added box provider doesnt match expected: #{log_provider}")
                raise Errors::BoxProviderDoesntMatch,
                  expected: log_provider, actual: box_provider
              end
            else
              check_box_exists.call([box_provider])
            end

            provider = box_provider.to_sym

            root_box_dir = @directory.join(dir_name(name))
            box_dir = root_box_dir.join(version)
            box_dir.mkpath
            @logger.debug("Box directory: #{box_dir}")

            final_dir = box_dir.join(provider.to_s)
            if final_dir.exist?
              @logger.debug("Removing existing provider directory...")
              final_dir.rmtree
            end

            final_dir.mkpath

            copy_pairs = [[final_temp_dir, final_dir]]
            while !copy_pairs.empty?
              from, to = copy_pairs.shift
              from.children(true).each do |f|
                dest = to.join(f.basename)

                if f.directory?
                  dest.mkpath
                  copy_pairs << [f, dest]
                  next
                end

                @logger.debug("Moving: #{f} => #{dest}")
                FileUtils.mv(f, dest)
              end
            end

            if opts[:metadata_url]
              root_box_dir.join("metadata_url").open("w") do |f|
                f.write(opts[:metadata_url])
              end
            end
          end
        end
      end

      find(name, provider, version)
    end

    def all
      results = []

      with_collection_lock do
        @logger.debug("Finding all boxes in: #{@directory}")
        @directory.children(true).each do |child|
          next if !child.directory?

          box_name = undir_name(child.basename.to_s)

          child.children(true).each do |versiondir|
            next if !versiondir.directory?
            next if versiondir.basename.to_s.start_with?(".")

            version = versiondir.basename.to_s

            versiondir.children(true).each do |provider|
              if provider.directory? && provider.join("metadata.json").file?
                provider_name = provider.basename.to_s.to_sym
                @logger.debug("Box: #{box_name} (#{provider_name})")
                results << [box_name, version, provider_name]
              else
                @logger.debug("Invalid box, ignoring: #{provider}")
              end
            end
          end
        end
      end

      results
    end

    def find(name, providers, version)
      providers = Array(providers)

      requirements = version.to_s.split(",").map do |v|
        Gem::Requirement.new(v.strip)
      end

      with_collection_lock do
        box_directory = @directory.join(dir_name(name))
        if !box_directory.directory?
          @logger.info("Box not found: #{name} (#{providers.join(", ")})")
          return nil
        end

        versions = box_directory.children(true).map do |versiondir|
          next if !versiondir.directory?
          next if versiondir.basename.to_s.start_with?(".")

          version = versiondir.basename.to_s
          Gem::Version.new(version)
        end.compact

        versions.sort.reverse.each do |v|
          if !requirements.all? { |r| r.satisfied_by?(v) }
            next
          end

          versiondir = box_directory.join(v.to_s)
          providers.each do |provider|
            provider_dir = versiondir.join(provider.to_s)
            next if !provider_dir.directory?
            @logger.info("Box found: #{name} (#{provider})")

            metadata_url = nil
            metadata_url_file = box_directory.join("metadata_url")
            metadata_url = metadata_url_file.read if metadata_url_file.file?

            if metadata_url && @hook
              hook_env     = @hook.call(
                :authenticate_box_url, box_urls: [metadata_url])
              metadata_url = hook_env[:box_urls].first
            end

            return Box.new(
              name, provider, v.to_s, provider_dir,
              metadata_url: metadata_url,
            )
          end
        end
      end

      nil
    end

    def upgrade_v1_1_v1_5
      with_collection_lock do
        temp_dir = Pathname.new(Dir.mktmpdir(TEMP_PREFIX, @temp_root))

        @directory.children(true).each do |boxdir|
          next if !boxdir.directory?

          box_name = boxdir.basename.to_s

          if v1_box?(boxdir)
            upgrade_dir = v1_upgrade(boxdir)
            FileUtils.mv(upgrade_dir, boxdir.join("virtualbox"))
          end

          new_box_dir = temp_dir.join(dir_name(box_name), "0")
          new_box_dir.mkpath

          boxdir.children(true).each do |providerdir|
            FileUtils.cp_r(providerdir, new_box_dir.join(providerdir.basename))
          end
        end

        @directory.rmtree
        FileUtils.mv(temp_dir.to_s, @directory.to_s)
      end
    end

    protected

    def dir_name(name)
      name = name.dup
      name.gsub!(":", "-VAGRANTCOLON-") if Util::Platform.windows?
      name.gsub!("/", "-VAGRANTSLASH-")
      name
    end

    def undir_name(name)
      name = name.dup
      name.gsub!("-VAGRANTCOLON-", ":")
      name.gsub!("-VAGRANTSLASH-", "/")
      name
    end

    def v1_box?(dir)
      dir.join("box.ovf").file?
    end

    def v1_upgrade(dir)
      @logger.debug("Upgrading box in directory: #{dir}")

      temp_dir = Pathname.new(Dir.mktmpdir(TEMP_PREFIX, @temp_root))
      @logger.debug("Temporary directory for upgrading: #{temp_dir}")

      dir.children(true).each do |child|
        next if child == temp_dir

        @logger.debug("Copying to upgrade directory: #{child}")
        FileUtils.mv(child, temp_dir.join(child.basename))
      end

      metadata_file = temp_dir.join("metadata.json")
      if !metadata_file.file?
        metadata_file.open("w") do |f|
          f.write(JSON.generate({
            provider: "virtualbox"
          }))
        end
      end

      temp_dir
    end

    def with_collection_lock
      @lock.synchronize do
        return yield
      end
    end

    def with_temp_dir(dir=nil)
      dir ||= Dir.mktmpdir(TEMP_PREFIX, @temp_root)
      dir = Pathname.new(dir)

      yield dir
    ensure
      dir.rmtree if dir.exist?
    end
  end
end
