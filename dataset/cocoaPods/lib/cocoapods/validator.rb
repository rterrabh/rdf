require 'active_support/core_ext/array'
require 'active_support/core_ext/string/inflections'

module Pod
  class Validator
    include Config::Mixin

    attr_reader :linter

    def initialize(spec_or_path, source_urls)
      @source_urls = source_urls.map { |url| SourcesManager.source_with_name_or_url(url) }.map(&:url)
      @linter = Specification::Linter.new(spec_or_path)
    end


    def spec
      @linter.spec
    end

    def file
      @linter.file
    end

    attr_accessor :file_accessor


    def validate
      @results = []

      a_spec = spec
      if spec && @only_subspec
        a_spec = spec.subspec_by_name(@only_subspec)
        @subspec_name = a_spec.name
      end

      UI.print " -> #{a_spec ? a_spec.name : file.basename}\r" unless config.silent?
      $stdout.flush

      perform_linting
      perform_extensive_analysis(a_spec) if a_spec && !quick

      #nodyna <send-2686> <SD MODERATE (change-prone variables)>
      UI.puts ' -> '.send(result_color) << (a_spec ? a_spec.to_s : file.basename.to_s)
      print_results
      validated?
    end

    def print_results
      results.each do |result|
        if result.platforms == [:ios]
          platform_message = '[iOS] '
        elsif result.platforms == [:osx]
          platform_message = '[OSX] '
        elsif result.platforms == [:watchos]
          platform_message = '[watchOS] '
        end

        subspecs_message = ''
        if result.is_a?(Result)
          subspecs = result.subspecs.uniq
          if subspecs.count > 2
            subspecs_message = '[' + subspecs[0..2].join(', ') + ', and more...] '
          elsif subspecs.count > 0
            subspecs_message = '[' + subspecs.join(',') + '] '
          end
        end

        case result.type
        when :error   then type = 'ERROR'
        when :warning then type = 'WARN'
        when :note    then type = 'NOTE'
        else raise "#{result.type}" end
        UI.puts "    - #{type.ljust(5)} | #{platform_message}#{subspecs_message}#{result.attribute_name}: #{result.message}"
      end
      UI.puts
    end

    def failure_reason
      results_by_type = results.group_by(&:type)
      results_by_type.default = []
      return nil if validated?
      reasons = []
      if (size = results_by_type[:error].size) && size > 0
        reasons << "#{size} #{'error'.pluralize(size)}"
      end
      if !allow_warnings && (size = results_by_type[:warning].size) && size > 0
        reason = "#{size} #{'warning'.pluralize(size)}"
        pronoun = size == 1 ? 'it' : 'them'
        reason << " (but you can use `--allow-warnings` to ignore #{pronoun})" if reasons.empty?
        reasons << reason
      end
      if results.all?(&:public_only)
        reasons << 'All results apply only to public specs, but you can use ' \
                   '`--private` to ignore them if linting the specification for a private pod.'
      end
      reasons.to_sentence
    end



    attr_accessor :quick

    attr_accessor :no_clean

    attr_accessor :fail_fast

    attr_accessor :local
    alias_method :local?, :local

    attr_accessor :allow_warnings

    attr_accessor :only_subspec

    attr_accessor :no_subspecs

    attr_accessor :use_frameworks

    attr_accessor :ignore_public_only_results



    attr_reader :results

    def validated?
      result_type != :error && (result_type != :warning || allow_warnings)
    end

    def result_type
      applicable_results = results
      applicable_results = applicable_results.reject(&:public_only?) if ignore_public_only_results
      types              = applicable_results.map(&:type).uniq
      if    types.include?(:error)   then :error
      elsif types.include?(:warning) then :warning
      else  :note
      end
    end

    def result_color
      case result_type
      when :error   then :red
      when :warning then :yellow
      else :green end
    end

    def validation_dir
      Pathname(Dir.tmpdir) + 'CocoaPods/Lint'
    end


    private


    def perform_linting
      linter.lint
      @results.concat(linter.results.to_a)
    end

    def perform_extensive_analysis(spec)
      validate_homepage(spec)
      validate_screenshots(spec)
      validate_social_media_url(spec)
      validate_documentation_url(spec)
      validate_docset_url(spec)

      #nodyna <send-2687> <SD MODERATE (change-prone variables)>
      valid = spec.available_platforms.send(fail_fast ? :all? : :each) do |platform|
        UI.message "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed
        @consumer = spec.consumer(platform)
        setup_validation_environment
        download_pod
        check_file_patterns
        install_pod
        validate_vendored_dynamic_frameworks
        build_pod
        tear_down_validation_environment
        validated?
      end
      return false if fail_fast && !valid
      perform_extensive_subspec_analysis(spec) unless @no_subspecs
    rescue => e
      error('unknown', "Encountered an unknown error (#{e}) during validation.")
      false
    end

    def perform_extensive_subspec_analysis(spec)
      #nodyna <send-2688> <SD MODERATE (change-prone variables)>
      spec.subspecs.send(fail_fast ? :all? : :each) do |subspec|
        @subspec_name = subspec.name
        perform_extensive_analysis(subspec)
      end
    end

    attr_accessor :consumer
    attr_accessor :subspec_name

    def validate_url(url)
      resp = Pod::HTTP.validate_url(url)

      if !resp
        warning('url', "There was a problem validating the URL #{url}.", true)
      elsif !resp.success?
        warning('url', "The URL (#{url}) is not reachable.", true)
      end

      resp
    end

    def validate_homepage(spec)
      if spec.homepage
        validate_url(spec.homepage)
      end
    end

    def validate_screenshots(spec)
      spec.screenshots.compact.each do |screenshot|
        response = validate_url(screenshot)
        if response && !(response.headers['content-type'] && response.headers['content-type'].first =~ /image\/.*/i)
          warning('screenshot', "The screenshot #{screenshot} is not a valid image.")
        end
      end
    end

    def validate_social_media_url(spec)
      validate_url(spec.social_media_url) if spec.social_media_url
    end

    def validate_documentation_url(spec)
      validate_url(spec.documentation_url) if spec.documentation_url
    end

    def validate_docset_url(spec)
      validate_url(spec.docset_url) if spec.docset_url
    end

    def setup_validation_environment
      validation_dir.rmtree if validation_dir.exist?
      validation_dir.mkpath
      @original_config = Config.instance.clone
      config.installation_root = validation_dir
      config.sandbox_root      = validation_dir + 'Pods'
      config.silent            = !config.verbose
      config.integrate_targets = false
      config.skip_repo_update  = true
    end

    def tear_down_validation_environment
      validation_dir.rmtree unless no_clean
      Config.instance = @original_config
    end

    def download_pod
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)
      podfile = podfile_from_spec(consumer.platform_name, deployment_target, use_frameworks)
      sandbox = Sandbox.new(config.sandbox_root)
      @installer = Installer.new(sandbox, podfile)
      @installer.use_default_plugins = false
      #nodyna <send-2689> <SD MODERATE (array)>
      %i(prepare resolve_dependencies download_dependencies).each { |m| @installer.send(m) }
      @file_accessor = @installer.pod_targets.flat_map(&:file_accessors).find { |fa| fa.spec.name == consumer.spec.name }
    end

    def install_pod
      %i(determine_dependency_product_types verify_no_duplicate_framework_names
         verify_no_static_framework_transitive_dependencies
         verify_framework_usage generate_pods_project
         #nodyna <send-2690> <SD MODERATE (array)>
         perform_post_install_actions).each { |m| @installer.send(m) }

      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)
      @installer.aggregate_targets.each do |target|
        if target.pod_targets.any?(&:uses_swift?) && consumer.platform_name == :ios &&
            (deployment_target.nil? || Version.new(deployment_target).major < 8)
          uses_xctest = target.spec_consumers.any? { |c| (c.frameworks + c.weak_frameworks).include? 'XCTest' }
          error('swift', 'Swift support uses dynamic frameworks and is therefore only supported on iOS > 8.') unless uses_xctest
        end
      end
    end

    def validate_vendored_dynamic_frameworks
      deployment_target = spec.subspec_by_name(subspec_name).deployment_target(consumer.platform_name)

      unless file_accessor.nil?
        dynamic_frameworks = file_accessor.vendored_dynamic_frameworks
        dynamic_libraries = file_accessor.vendored_dynamic_libraries
        if (dynamic_frameworks.count > 0 || dynamic_libraries.count > 0) && consumer.platform_name == :ios &&
            (deployment_target.nil? || Version.new(deployment_target).major < 8)
          error('dynamic', 'Dynamic frameworks and libraries are only supported on iOS 8.0 and onwards.')
        end
      end
    end

    def build_pod
      if Executable.which('xcodebuild').nil?
        UI.warn "Skipping compilation with `xcodebuild' because it can't be found.\n".yellow
      else
        UI.message "\nBuilding with xcodebuild.\n".yellow do
          output = Dir.chdir(config.sandbox_root) { xcodebuild }
          UI.puts output
          parsed_output = parse_xcodebuild_output(output)
          parsed_output.each do |message|
            if message.include?("'InputFile' should have")
              next
            end

            if message =~ /\S+:\d+:\d+: error:/
              error('xcodebuild', message)
            elsif message =~ /\S+:\d+:\d+: warning:/
              warning('xcodebuild', message)
            else
              note('xcodebuild', message)
            end
          end
        end
      end
    end

    FILE_PATTERNS = %i(source_files resources preserve_paths vendored_libraries
                       vendored_frameworks public_header_files preserve_paths
                       private_header_files resource_bundles).freeze

    def check_file_patterns
      FILE_PATTERNS.each do |attr_name|
        if respond_to?("_validate_#{attr_name}", true)
          #nodyna <send-2691> <SD MODERATE (array)>
          send("_validate_#{attr_name}")
        end

        #nodyna <send-2692> <SD MODERATE (array)>
        #nodyna <send-2693> <SD MODERATE (array)>
        if !file_accessor.spec_consumer.send(attr_name).empty? && file_accessor.send(attr_name).empty?
          error('file patterns', "The `#{attr_name}` pattern did not match any file.")
        end
      end

      if consumer.spec.root?
        _validate_license
        _validate_module_map
      end
    end

    def _validate_private_header_files
      _validate_header_files(:private_header_files)
    end

    def _validate_public_header_files
      _validate_header_files(:public_header_files)
    end

    def _validate_license
      unless file_accessor.license || spec.license && (spec.license[:type] == 'Public Domain' || spec.license[:text])
        warning('license', 'Unable to find a license file')
      end
    end

    def _validate_module_map
      if spec.module_map
        unless file_accessor.module_map.exist?
          error('module_map', 'Unable to find the specified module map file.')
        end
        unless file_accessor.module_map.extname == '.modulemap'
          relative_path = file_accessor.module_map.relative_path_from file_accessor.root
          error('module_map', "Unexpected file extension for modulemap file (#{relative_path}).")
        end
      end
    end

    def _validate_header_files(attr_name)
      #nodyna <send-2694> <SD MODERATE (change-prone variables)>
      non_header_files = file_accessor.send(attr_name).
        select { |f| !Sandbox::FileAccessor::HEADER_EXTENSIONS.include?(f.extname) }.
        map { |f| f.relative_path_from file_accessor.root }
      unless non_header_files.empty?
        error(attr_name, "The pattern matches non-header files (#{non_header_files.join(', ')}).")
      end
    end


    private


    def error(*args)
      add_result(:error, *args)
    end

    def warning(*args)
      add_result(:warning, *args)
    end

    def note(*args)
      add_result(:note, *args)
    end

    def add_result(type, attribute_name, message, public_only = false)
      result = results.find do |r|
        r.type == type && r.attribute_name && r.message == message && r.public_only? == public_only
      end
      unless result
        result = Result.new(type, attribute_name, message, public_only)
        results << result
      end
      result.platforms << consumer.platform_name if consumer
      result.subspecs << subspec_name if subspec_name && !result.subspecs.include?(subspec_name)
    end

    class Result < Specification::Linter::Results::Result
      def initialize(type, attribute_name, message, public_only = false)
        super(type, attribute_name, message, public_only)
        @subspecs = []
      end

      attr_reader :subspecs
    end


    private


    attr_reader :source_urls

    def podfile_from_spec(platform_name, deployment_target, use_frameworks = true)
      name     = subspec_name || spec.name
      podspec  = file.realpath
      local    = local?
      urls     = source_urls
      Pod::Podfile.new do
        urls.each { |u| source(u) }
        use_frameworks!(use_frameworks)
        platform(platform_name, deployment_target)
        if local
          pod name, :path => podspec.dirname.to_s
        else
          pod name, :podspec => podspec.to_s
        end
      end
    end

    def parse_xcodebuild_output(output)
      lines = output.split("\n")
      selected_lines = lines.select do |l|
        l.include?('error: ') && (l !~ /errors? generated\./) && (l !~ /error: \(null\)/) ||
          l.include?('warning: ') && (l !~ /warnings? generated\./) && (l !~ /frameworks only run on iOS 8/) ||
          l.include?('note: ') && (l !~ /expanded from macro/)
      end
      selected_lines.map do |l|
        new = l.gsub(%r{#{validation_dir}/Pods/}, '')
        new.gsub!(/^ */, ' ')
      end
    end

    def xcodebuild
      command = 'xcodebuild clean build -target Pods'
      command << ' CODE_SIGN_IDENTITY=- -sdk iphonesimulator' if consumer.platform_name == :ios
      output, status = _xcodebuild "#{command} 2>&1"

      unless status.success?
        message = 'Returned an unsuccessful exit code.'
        message += ' You can use `--verbose` for more information.' unless config.verbose?
        error('xcodebuild', message)
      end

      output
    end

    def _xcodebuild(command)
      UI.puts command if config.verbose
      output = `#{command}`
      [output, $?]
    end

  end
end
