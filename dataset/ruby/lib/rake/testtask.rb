require 'rake'
require 'rake/tasklib'

module Rake

  class TestTask < TaskLib

    attr_accessor :name

    attr_accessor :libs

    attr_accessor :verbose

    attr_accessor :options

    attr_accessor :warning

    attr_accessor :pattern

    attr_accessor :loader

    attr_accessor :ruby_opts

    attr_accessor :description

    def test_files=(list)
      @test_files = list
    end

    def initialize(name=:test)
      @name = name
      @libs = ["lib"]
      @pattern = nil
      @options = nil
      @test_files = nil
      @verbose = false
      @warning = false
      @loader = :rake
      @ruby_opts = []
      @description = "Run tests" + (@name == :test ? "" : " for #{@name}")
      yield self if block_given?
      @pattern = 'test/test*.rb' if @pattern.nil? && @test_files.nil?
      define
    end

    def define
      desc @description
      task @name do
        FileUtilsExt.verbose(@verbose) do
          args =
            "#{ruby_opts_string} #{run_code} " +
            "#{file_list_string} #{option_list}"
          ruby args do |ok, status|
            if !ok && status.respond_to?(:signaled?) && status.signaled?
              raise SignalException.new(status.termsig)
            elsif !ok
              fail "Command failed with status (#{status.exitstatus}): " +
                "[ruby #{args}]"
            end
          end
        end
      end
      self
    end

    def option_list # :nodoc:
      (ENV['TESTOPTS'] ||
        ENV['TESTOPT'] ||
        ENV['TEST_OPTS'] ||
        ENV['TEST_OPT'] ||
        @options ||
        "")
    end

    def ruby_opts_string # :nodoc:
      opts = @ruby_opts.dup
      opts.unshift("-I\"#{lib_path}\"") unless @libs.empty?
      opts.unshift("-w") if @warning
      opts.join(" ")
    end

    def lib_path # :nodoc:
      @libs.join(File::PATH_SEPARATOR)
    end

    def file_list_string # :nodoc:
      file_list.map { |fn| "\"#{fn}\"" }.join(' ')
    end

    def file_list # :nodoc:
      if ENV['TEST']
        FileList[ENV['TEST']]
      else
        result = []
        result += @test_files.to_a if @test_files
        result << @pattern if @pattern
        result
      end
    end

    def fix # :nodoc:
      case ruby_version
      when '1.8.2'
        "\"#{find_file 'rake/ruby182_test_unit_fix'}\""
      else
        nil
      end || ''
    end

    def ruby_version # :nodoc:
      RUBY_VERSION
    end

    def run_code # :nodoc:
      case @loader
      when :direct
        "-e \"ARGV.each{|f| require f}\""
      when :testrb
        "-S testrb #{fix}"
      when :rake
        "#{rake_include_arg} \"#{rake_loader}\""
      end
    end

    def rake_loader # :nodoc:
      find_file('rake/rake_test_loader') or
        fail "unable to find rake test loader"
    end

    def find_file(fn) # :nodoc:
      $LOAD_PATH.each do |path|
        file_path = File.join(path, "#{fn}.rb")
        return file_path if File.exist? file_path
      end
      nil
    end

    def rake_include_arg # :nodoc:
      spec = Gem.loaded_specs['rake']
      if spec.respond_to?(:default_gem?) && spec.default_gem?
        ""
      else
        "-I\"#{rake_lib_dir}\""
      end
    end

    def rake_lib_dir # :nodoc:
      find_dir('rake') or
        fail "unable to find rake lib"
    end

    def find_dir(fn) # :nodoc:
      $LOAD_PATH.each do |path|
        file_path = File.join(path, "#{fn}.rb")
        return path if File.exist? file_path
      end
      nil
    end

  end
end
