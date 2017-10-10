
require 'optparse'
require 'rubygems/requirement'
require 'rubygems/user_interaction'


class Gem::Command

  include Gem::UserInteraction


  attr_reader :command


  attr_reader :options


  attr_accessor :defaults


  attr_accessor :program_name


  attr_accessor :summary


  def self.build_args
    @build_args ||= []
  end

  def self.build_args=(value)
    @build_args = value
  end

  def self.common_options
    @common_options ||= []
  end

  def self.add_common_option(*args, &handler)
    Gem::Command.common_options << [args, handler]
  end

  def self.extra_args
    @extra_args ||= []
  end

  def self.extra_args=(value)
    case value
    when Array
      @extra_args = value
    when String
      @extra_args = value.split
    end
  end


  def self.specific_extra_args(cmd)
    specific_extra_args_hash[cmd]
  end


  def self.add_specific_extra_args(cmd,args)
    args = args.split(/\s+/) if args.kind_of? String
    specific_extra_args_hash[cmd] = args
  end


  def self.specific_extra_args_hash
    @specific_extra_args_hash ||= Hash.new do |h,k|
      h[k] = Array.new
    end
  end


  def initialize(command, summary=nil, defaults={})
    @command = command
    @summary = summary
    @program_name = "gem #{command}"
    @defaults = defaults
    @options = defaults.dup
    @option_groups = Hash.new { |h,k| h[k] = [] }
    @parser = nil
    @when_invoked = nil
  end


  def begins?(long, short)
    return false if short.nil?
    long[0, short.length] == short
  end


  def execute
    raise Gem::Exception, "generic command has no actions"
  end


  def show_lookup_failure(gem_name, version, errors, domain)
    if errors and !errors.empty?
      msg = "Could not find a valid gem '#{gem_name}' (#{version}), here is why:\n"
      errors.each { |x| msg << "          #{x.wordy}\n" }
      alert_error msg
    else
      alert_error "Could not find a valid gem '#{gem_name}' (#{version}) in any repository"
    end

    unless domain == :local then # HACK
      suggestions = Gem::SpecFetcher.fetcher.suggest_gems_from_name gem_name

      unless suggestions.empty?
        alert_error "Possible alternatives: #{suggestions.join(", ")}"
      end
    end
  end


  def get_all_gem_names
    args = options[:args]

    if args.nil? or args.empty? then
      raise Gem::CommandLineError,
            "Please specify at least one gem name (e.g. gem build GEMNAME)"
    end

    args.select { |arg| arg !~ /^-/ }
  end

  def get_all_gem_names_and_versions
    get_all_gem_names.map do |name|
      if /\A(.*):(#{Gem::Requirement::PATTERN_RAW})\z/ =~ name
        [$1, $2]
      else
        [name]
      end
    end
  end


  def get_one_gem_name
    args = options[:args]

    if args.nil? or args.empty? then
      raise Gem::CommandLineError,
            "Please specify a gem name on the command line (e.g. gem build GEMNAME)"
    end

    if args.size > 1 then
      raise Gem::CommandLineError,
            "Too many gem names (#{args.join(', ')}); please specify only one"
    end

    args.first
  end


  def get_one_optional_argument
    args = options[:args] || []
    args.first
  end


  def arguments
    ""
  end


  def defaults_str
    ""
  end


  def description
    nil
  end


  def usage
    program_name
  end


  def show_help
    parser.program_name = usage
    say parser
  end


  def invoke(*args)
    invoke_with_build_args args, nil
  end


  def invoke_with_build_args(args, build_args)
    handle_options args

    options[:build_args] = build_args

    if options[:help] then
      show_help
    elsif @when_invoked then
      @when_invoked.call options
    else
      execute
    end
  end


  def when_invoked(&block)
    @when_invoked = block
  end


  def add_option(*opts, &handler) # :yields: value, options
    group_name = Symbol === opts.first ? opts.shift : :options

    @option_groups[group_name] << [opts, handler]
  end


  def remove_option(name)
    @option_groups.each do |_, option_list|
      option_list.reject! { |args, _| args.any? { |x| x =~ /^#{name}/ } }
    end
  end


  def merge_options(new_options)
    @options = @defaults.clone
    new_options.each do |k,v| @options[k] = v end
  end


  def handles?(args)
    begin
      parser.parse!(args.dup)
      return true
    rescue
      return false
    end
  end


  def handle_options(args)
    args = add_extra_args(args)
    @options = Marshal.load Marshal.dump @defaults # deep copy
    parser.parse!(args)
    @options[:args] = args
  end


  def add_extra_args(args)
    result = []

    s_extra = Gem::Command.specific_extra_args(@command)
    extra = Gem::Command.extra_args + s_extra

    until extra.empty? do
      ex = []
      ex << extra.shift
      ex << extra.shift if extra.first.to_s =~ /^[^-]/
      result << ex if handles?(ex)
    end

    result.flatten!
    result.concat(args)
    result
  end

  private

  def add_parser_description # :nodoc:
    return unless description

    formatted = description.split("\n\n").map do |chunk|
      wrap chunk, 80 - 4
    end.join "\n"

    @parser.separator nil
    @parser.separator "  Description:"
    formatted.split("\n").each do |line|
      @parser.separator "    #{line.rstrip}"
    end
  end

  def add_parser_options # :nodoc:
    @parser.separator nil

    regular_options = @option_groups.delete :options

    configure_options "", regular_options

    @option_groups.sort_by { |n,_| n.to_s }.each do |group_name, option_list|
      @parser.separator nil
      configure_options group_name, option_list
    end
  end


  def add_parser_run_info title, content
    return if content.empty?

    @parser.separator nil
    @parser.separator "  #{title}:"
    content.split(/\n/).each do |line|
      @parser.separator "    #{line}"
    end
  end

  def add_parser_summary # :nodoc:
    return unless @summary

    @parser.separator nil
    @parser.separator "  Summary:"
    wrap(@summary, 80 - 4).split("\n").each do |line|
      @parser.separator "    #{line.strip}"
    end
  end


  def parser
    create_option_parser if @parser.nil?
    @parser
  end


  def create_option_parser
    @parser = OptionParser.new

    add_parser_options

    @parser.separator nil
    configure_options "Common", Gem::Command.common_options

    add_parser_run_info "Arguments", arguments
    add_parser_summary
    add_parser_description
    add_parser_run_info "Defaults", defaults_str
  end

  def configure_options(header, option_list)
    return if option_list.nil? or option_list.empty?

    header = header.to_s.empty? ? '' : "#{header} "
    @parser.separator "  #{header}Options:"

    option_list.each do |args, handler|
      args.select { |arg| arg =~ /^-/ }
      @parser.on(*args) do |value|
        handler.call(value, @options)
      end
    end

    @parser.separator ''
  end


  def wrap(text, width) # :doc:
    text.gsub(/(.{1,#{width}})( +|$\n?)|(.{1,#{width}})/, "\\1\\3\n")
  end


  add_common_option('-h', '--help',
                    'Get help on this command') do |value, options|
    options[:help] = true
  end

  add_common_option('-V', '--[no-]verbose',
                    'Set the verbose level of output') do |value, options|
    if Gem.configuration.verbose and value then
      Gem.configuration.verbose = 1
    else
      Gem.configuration.verbose = value
    end
  end

  add_common_option('-q', '--quiet', 'Silence commands') do |value, options|
    Gem.configuration.verbose = false
  end


  add_common_option('--config-file FILE',
                    'Use this config file instead of default') do
  end

  add_common_option('--backtrace',
                    'Show stack backtrace on errors') do
  end

  add_common_option('--debug',
                    'Turn on Ruby debugging') do
  end


  HELP = <<-HELP
RubyGems is a sophisticated package manager for Ruby.  This is a
basic help message containing pointers to more information.

  Usage:
    gem -h/--help
    gem -v/--version
    gem command [arguments...] [options...]

  Examples:
    gem install rake
    gem list --local
    gem build package.gemspec
    gem help install

  Further help:
    gem help commands            list all 'gem' commands
    gem help examples            show some examples of usage
    gem help gem_dependencies    gem dependencies file guide
    gem help platforms           gem platforms guide
    gem help <COMMAND>           show help on COMMAND
                                   (e.g. 'gem help install')
    gem server                   present a web page at
                                 http://localhost:8808/
                                 with info about installed gems
  Further information:
    http://guides.rubygems.org
  HELP


end


module Gem::Commands
end

