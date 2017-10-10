require 'rubygems'
require 'rubygems/user_interaction'
require 'fileutils'
require 'rdoc'


class RDoc::RubygemsHook

  include Gem::UserInteraction
  extend  Gem::UserInteraction

  @rdoc_version = nil
  @specs = []


  attr_accessor :force


  attr_accessor :generate_rdoc


  attr_accessor :generate_ri

  class << self


    attr_reader :rdoc_version

  end


  def self.generation_hook installer, specs
    start = Time.now
    types = installer.document

    generate_rdoc = types.include? 'rdoc'
    generate_ri   = types.include? 'ri'

    specs.each do |spec|
      new(spec, generate_rdoc, generate_ri).generate
    end

    return unless generate_rdoc or generate_ri

    duration = (Time.now - start).to_i
    names    = specs.map(&:name).join ', '

    say "Done installing documentation for #{names} after #{duration} seconds"
  end


  def self.load_rdoc
    return if @rdoc_version

    require 'rdoc/rdoc'

    @rdoc_version = Gem::Version.new ::RDoc::VERSION
  end


  def initialize spec, generate_rdoc = false, generate_ri = true
    @doc_dir   = spec.doc_dir
    @force     = false
    @rdoc      = nil
    @spec      = spec

    @generate_rdoc = generate_rdoc
    @generate_ri   = generate_ri

    @rdoc_dir = spec.doc_dir 'rdoc'
    @ri_dir   = spec.doc_dir 'ri'
  end


  def delete_legacy_args args
    args.delete '--inline-source'
    args.delete '--promiscuous'
    args.delete '-p'
    args.delete '--one-file'
  end


  def document generator, options, destination
    generator_name = generator

    options = options.dup
    options.exclude ||= [] # TODO maybe move to RDoc::Options#finish
    options.setup_generator generator
    options.op_dir = destination
    options.finish

    generator = options.generator.new @rdoc.store, options

    @rdoc.options = options
    @rdoc.generator = generator

    say "Installing #{generator_name} documentation for #{@spec.full_name}"

    FileUtils.mkdir_p options.op_dir

    Dir.chdir options.op_dir do
      begin
        @rdoc.class.current = @rdoc
        @rdoc.generator.generate
      ensure
        @rdoc.class.current = nil
      end
    end
  end


  def generate
    return if @spec.default_gem?
    return unless @generate_ri or @generate_rdoc

    setup

    options = nil

    args = @spec.rdoc_options

    if @spec.respond_to? :source_paths then
      args.concat @spec.source_paths
    else
      args.concat @spec.require_paths
    end

    args.concat @spec.extra_rdoc_files

    case config_args = Gem.configuration[:rdoc]
    when String then
      args = args.concat config_args.split
    when Array then
      args = args.concat config_args
    end

    delete_legacy_args args

    Dir.chdir @spec.full_gem_path do
      options = ::RDoc::Options.new
      options.default_title = "#{@spec.full_name} Documentation"
      options.parse args
    end

    options.quiet = !Gem.configuration.really_verbose

    @rdoc = new_rdoc
    @rdoc.options = options

    store = RDoc::Store.new
    store.encoding = options.encoding if options.respond_to? :encoding
    store.dry_run  = options.dry_run
    store.main     = options.main_page
    store.title    = options.title

    @rdoc.store = store

    say "Parsing documentation for #{@spec.full_name}"

    Dir.chdir @spec.full_gem_path do
      @rdoc.parse_files options.files
    end

    document 'ri',       options, @ri_dir if
      @generate_ri   and (@force or not File.exist? @ri_dir)

    document 'darkfish', options, @rdoc_dir if
      @generate_rdoc and (@force or not File.exist? @rdoc_dir)
  end


  def new_rdoc # :nodoc:
    ::RDoc::RDoc.new
  end


  def rdoc_installed?
    File.exist? @rdoc_dir
  end


  def remove
    base_dir = @spec.base_dir

    raise Gem::FilePermissionError, base_dir unless File.writable? base_dir

    FileUtils.rm_rf @rdoc_dir
    FileUtils.rm_rf @ri_dir
  end


  def ri_installed?
    File.exist? @ri_dir
  end


  def setup
    self.class.load_rdoc

    raise Gem::FilePermissionError, @doc_dir if
      File.exist?(@doc_dir) and not File.writable?(@doc_dir)

    FileUtils.mkdir_p @doc_dir unless File.exist? @doc_dir
  end

end

