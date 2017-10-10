module Pod
  class SourcesManager
    class << self
      include Config::Mixin

      def aggregate
        return Source::Aggregate.new([]) unless config.repos_dir.exist?
        dirs = config.repos_dir.children.select(&:directory?)
        Source::Aggregate.new(dirs)
      end

      def sources(names)
        dirs = names.map { |name| source_dir(name) }
        dirs.map { |repo| Source.new(repo) }
      end

      def find_or_create_source_with_url(url)
        unless source = source_with_url(url)
          name = name_for_url(url)
          previous_title_level = UI.title_level
          UI.title_level = 0
          begin
            argv = [name, url]
            argv << '--shallow' if name =~ /^master(-\d+)?$/
            Command::Repo::Add.new(CLAide::ARGV.new(argv)).run
          rescue Informative
            raise Informative, "Unable to add a source with url `#{url}` " \
              "named `#{name}`.\nYou can try adding it manually in " \
              '`~/.cocoapods/repos` or via `pod repo add`.'
          ensure
            UI.title_level = previous_title_level
          end
          source = source_with_url(url)
        end

        source
      end

      def source_with_name_or_url(name_or_url)
        all.find { |s| s.name == name_or_url } ||
          find_or_create_source_with_url(name_or_url)
      end

      def all
        return [] unless config.repos_dir.exist?
        dirs = config.repos_dir.children.select(&:directory?)
        dirs.map { |repo| Source.new(repo) }
      end

      def master
        sources(['master'])
      end

      def search(dependency)
        aggregate.search(dependency)
      end

      def search_by_name(query, full_text_search = false)
        if full_text_search
          set_names = []
          query_regexp = /#{query}/i
          updated_search_index.each do |name, set_data|
            texts = [name]
            if full_text_search
              texts << set_data['authors'].to_s if set_data['authors']
              texts << set_data['summary']      if set_data['summary']
              texts << set_data['description']  if set_data['description']
            end
            set_names << name unless texts.grep(query_regexp).empty?
          end
          sets = set_names.sort.map do |name|
            aggregate.representative_set(name)
          end
        else
          sets = aggregate.search_by_name(query, false)
        end
        if sets.empty?
          extra = ', author, summary, or description' if full_text_search
          raise Informative, "Unable to find a pod with name#{extra}" \
            "matching `#{query}`"
        end
        sets
      end

      def updated_search_index
        unless @updated_search_index
          if search_index_path.exist?
            require 'yaml'
            stored_index = YAML.load(search_index_path.read)
            if stored_index && stored_index.is_a?(Hash)
              search_index = aggregate.update_search_index(stored_index)
            else
              search_index = aggregate.generate_search_index
            end
          else
            search_index = aggregate.generate_search_index
          end

          File.open(search_index_path, 'w') do |file|
            file.write(search_index.to_yaml)
          end
          @updated_search_index = search_index
        end
        @updated_search_index
      end

      attr_writer :updated_search_index

      def search_index_path
        Config.instance.search_index_file
      end


      extend Executable
      executable :git

      def update(source_name = nil, show_output = false)
        if source_name
          sources = [git_source_named(source_name)]
        else
          sources =  git_sources
        end

        sources.each do |source|
          UI.section "Updating spec repo `#{source.name}`" do
            Dir.chdir(source.repo) do
              begin
                output = git! %w(pull --ff-only)
                UI.puts output if show_output && !config.verbose?
              rescue Informative
                UI.warn 'CocoaPods was not able to update the ' \
                  "`#{source.name}` repo. If this is an unexpected issue " \
                  'and persists you can inspect it running ' \
                  '`pod repo update --verbose`'
              end
            end
            check_version_information(source.repo)
          end
        end
      end

      def git_repo?(dir)
        Dir.chdir(dir) { `git rev-parse >/dev/null 2>&1` }
        $?.success?
      end

      def check_version_information(dir)
        versions = version_information(dir)
        unless repo_compatible?(dir)
          min, max = versions['min'], versions['max']
          version_msg = (min == max) ? min : "#{min} - #{max}"
          raise Informative, "The `#{dir.basename}` repo requires " \
          "CocoaPods #{version_msg} (currently using #{Pod::VERSION})\n".red +
            'Update CocoaPods, or checkout the appropriate tag in the repo.'
        end

        needs_sudo = path_writable?(__FILE__)

        if config.new_version_message? && cocoapods_update?(versions)
          last = versions['last']
          rc = Gem::Version.new(last).prerelease?
          install_message = needs_sudo ? 'sudo ' : ''
          install_message << 'gem install cocoapods'
          install_message << ' --pre' if rc
          message = [
            "CocoaPods #{versions['last']} is available.".green,
            "To update use: `#{install_message}`".green,
            ("[!] This is a test version we'd love you to try.".yellow if rc),
            ("Until we reach version 1.0 the features of CocoaPods can and will change.\n" \
             'We strongly recommend that you use the latest version at all times.'.yellow unless rc),
            '',
            'For more information see http://blog.cocoapods.org'.green,
            'and the CHANGELOG for this version http://git.io/BaH8pQ.'.green,
            '',
          ].compact.join("\n")
          UI.puts("\n#{message}\n")
        end
      end

      def repo_compatible?(dir)
        versions = version_information(dir)

        min, max = versions['min'], versions['max']
        bin_version  = Gem::Version.new(Pod::VERSION)
        supports_min = !min || bin_version >= Gem::Version.new(min)
        supports_max = !max || bin_version <= Gem::Version.new(max)
        supports_min && supports_max
      end

      def cocoapods_update?(version_information)
        version = version_information['last']
        version && Gem::Version.new(version) > Gem::Version.new(Pod::VERSION)
      end

      def version_information(dir)
        require 'yaml'
        yaml_file  = dir + 'CocoaPods-version.yml'
        return {} unless yaml_file.exist?
        begin
          YAMLHelper.load_file(yaml_file)
        rescue Informative
          raise Informative, "There was an error reading '#{yaml_file}'.\n" \
            'Please consult http://blog.cocoapods.org/' \
            'Repairing-Our-Broken-Specs-Repository/ ' \
            'for more information.'
        end
      end


      def master_repo_dir
        config.repos_dir + 'master'
      end

      def master_repo_functional?
        master_repo_dir.exist? && repo_compatible?(master_repo_dir)
      end

      private

      def path_writable?(path)
        Pathname(path).dirname.writable?
      end

      def git_source_named(name)
        specified_source = aggregate.sources.find { |s| s.name == name }
        unless specified_source
          raise Informative, "Unable to find the `#{name}` repo."
        end
        unless git_repo?(specified_source.repo)
          raise Informative, "The `#{name}` repo is not a git repo."
        end
        specified_source
      end

      def git_sources
        all.select do |source|
          git_repo?(source.repo)
        end
      end

      def source_dir(name)
        if dir = config.repos_dir + name
          dir
        else
          raise Informative, "Unable to find the `#{name}` repo."
        end
      end

      def source_with_url(url)
        url = url.downcase.gsub(/.git$/, '')
        aggregate.sources.find do |source|
          source.url && source.url.downcase.gsub(/.git$/, '') == url
        end
      end

      def name_for_url(url)
        base_from_host_and_path = lambda do |host, path|
          if host
            base = host.split('.')[-2] || host
            base += '-'
          else
            base = ''
          end

          base + path.gsub(/.git$/, '').gsub(/^\//, '').split('/').join('-')
        end

        case url.to_s.downcase
        when %r{github.com[:/]+cocoapods/specs}
          base = 'master'
        when %r{github.com[:/]+(.+)/(.+)}
          base = Regexp.last_match[1]
        when /^\S+@(\S+)[:\/]+(.+)$/
          host, path = Regexp.last_match.captures
          base = base_from_host_and_path[host, path]
        when URI.regexp
          url = URI(url.downcase)
          base = base_from_host_and_path[url.host, url.path]
        else
          base = url.to_s.downcase
        end

        name = base
        infinity = 1.0 / 0
        (1..infinity).each do |i|
          break unless source_dir(name).exist?
          name = "#{base}-#{i}"
        end
        name
      end
    end
  end
end
