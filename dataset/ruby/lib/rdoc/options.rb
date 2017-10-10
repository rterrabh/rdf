require 'optparse'
require 'pathname'


class RDoc::Options


  DEPRECATED = {
    '--accessor'      => 'support discontinued',
    '--diagram'       => 'support discontinued',
    '--help-output'   => 'support discontinued',
    '--image-format'  => 'was an option for --diagram',
    '--inline-source' => 'source code is now always inlined',
    '--merge'         => 'ri now always merges class information',
    '--one-file'      => 'support discontinued',
    '--op-name'       => 'support discontinued',
    '--opname'        => 'support discontinued',
    '--promiscuous'   => 'files always only document their content',
    '--ri-system'     => 'Ruby installers use other techniques',
  }


  SPECIAL = %w[
    coverage_report
    dry_run
    encoding
    files
    force_output
    force_update
    generator
    generator_name
    generator_options
    generators
    op_dir
    option_parser
    pipe
    rdoc_include
    root
    static_path
    stylesheet_url
    template
    template_dir
    update_output_dir
    verbosity
    write_options
  ]


  Directory = Object.new


  Path = Object.new


  PathArray = Object.new


  Template = Object.new


  attr_accessor :charset


  attr_accessor :dry_run


  attr_accessor :encoding


  attr_accessor :exclude


  attr_accessor :files


  attr_accessor :force_output


  attr_accessor :force_update


  attr_accessor :formatter


  attr_accessor :generator


  attr_reader :generator_name # :nodoc:


  attr_accessor :generator_options


  attr_accessor :hyperlink_all


  attr_accessor :line_numbers


  attr_accessor :locale


  attr_accessor :locale_dir


  attr_accessor :main_page


  attr_accessor :markup


  attr_accessor :coverage_report


  attr_accessor :op_dir


  attr_accessor :option_parser

  attr_accessor :output_decoration


  attr_accessor :page_dir


  attr_accessor :pipe


  attr_accessor :rdoc_include


  attr_accessor :root


  attr_accessor :show_hash


  attr_accessor :static_path


  attr_accessor :tab_width


  attr_accessor :template


  attr_accessor :template_dir


  attr_accessor :template_stylesheets


  attr_accessor :title


  attr_accessor :update_output_dir


  attr_accessor :verbosity


  attr_accessor :webcvs


  attr_reader :visibility

  def initialize # :nodoc:
    init_ivars
  end

  def init_ivars # :nodoc:
    @dry_run = false
    @exclude = []
    @files = nil
    @force_output = false
    @force_update = true
    @generator = nil
    @generator_name = nil
    @generator_options = []
    @generators = RDoc::RDoc::GENERATORS
    @hyperlink_all = false
    @line_numbers = false
    @locale = nil
    @locale_name = nil
    @locale_dir = 'locale'
    @main_page = nil
    @markup = 'rdoc'
    @coverage_report = false
    @op_dir = nil
    @page_dir = nil
    @pipe = false
    @output_decoration = true
    @rdoc_include = []
    @root = Pathname(Dir.pwd)
    @show_hash = false
    @static_path = []
    @stylesheet_url = nil # TODO remove in RDoc 4
    @tab_width = 8
    @template = nil
    @template_dir = nil
    @template_stylesheets = []
    @title = nil
    @update_output_dir = true
    @verbosity = 1
    @visibility = :protected
    @webcvs = nil
    @write_options = false

    if Object.const_defined? :Encoding then
      @encoding = Encoding::UTF_8
      @charset = @encoding.name
    else
      @encoding = nil
      @charset = 'UTF-8'
    end
  end

  def init_with map # :nodoc:
    init_ivars

    encoding = map['encoding']
    @encoding = if Object.const_defined? :Encoding then
                  encoding ? Encoding.find(encoding) : encoding
                end

    @charset        = map['charset']
    @exclude        = map['exclude']
    @generator_name = map['generator_name']
    @hyperlink_all  = map['hyperlink_all']
    @line_numbers   = map['line_numbers']
    @locale_name    = map['locale_name']
    @locale_dir     = map['locale_dir']
    @main_page      = map['main_page']
    @markup         = map['markup']
    @op_dir         = map['op_dir']
    @show_hash      = map['show_hash']
    @tab_width      = map['tab_width']
    @template_dir   = map['template_dir']
    @title          = map['title']
    @visibility     = map['visibility']
    @webcvs         = map['webcvs']

    @rdoc_include = sanitize_path map['rdoc_include']
    @static_path  = sanitize_path map['static_path']
  end

  def yaml_initialize tag, map # :nodoc:
    init_with map
  end

  def == other # :nodoc:
    self.class === other and
      @encoding       == other.encoding       and
      @generator_name == other.generator_name and
      @hyperlink_all  == other.hyperlink_all  and
      @line_numbers   == other.line_numbers   and
      @locale         == other.locale         and
      @locale_dir     == other.locale_dir and
      @main_page      == other.main_page      and
      @markup         == other.markup         and
      @op_dir         == other.op_dir         and
      @rdoc_include   == other.rdoc_include   and
      @show_hash      == other.show_hash      and
      @static_path    == other.static_path    and
      @tab_width      == other.tab_width      and
      @template       == other.template       and
      @title          == other.title          and
      @visibility     == other.visibility     and
      @webcvs         == other.webcvs
  end


  def check_files
    @files.delete_if do |file|
      if File.exist? file then
        if File.readable? file then
          false
        else
          warn "file '#{file}' not readable"

          true
        end
      else
        warn "file '#{file}' not found"

        true
      end
    end
  end


  def check_generator
    if @generator then
      raise OptionParser::InvalidOption,
        "generator already set to #{@generator_name}"
    end
  end


  def default_title=(string)
    @title ||= string
  end


  def encode_with coder # :nodoc:
    encoding = @encoding ? @encoding.name : nil

    coder.add 'encoding', encoding
    coder.add 'static_path',  sanitize_path(@static_path)
    coder.add 'rdoc_include', sanitize_path(@rdoc_include)

    ivars = instance_variables.map { |ivar| ivar.to_s[1..-1] }
    ivars -= SPECIAL

    ivars.sort.each do |ivar|
      #nodyna <instance_variable_get-2024> <not yet classified>
      coder.add ivar, instance_variable_get("@#{ivar}")
    end
  end


  def finish
    @op_dir ||= 'doc'

    @rdoc_include << "." if @rdoc_include.empty?
    root = @root.to_s
    @rdoc_include << root unless @rdoc_include.include?(root)

    if @exclude.nil? or Regexp === @exclude then
    elsif @exclude.empty? then
      @exclude = nil
    else
      @exclude = Regexp.new(@exclude.join("|"))
    end

    finish_page_dir

    check_files


    unless @template then
      @template     = @generator_name
      @template_dir = template_dir_for @template
    end

    if @locale_name
      @locale = RDoc::I18n::Locale[@locale_name]
      @locale.load(@locale_dir)
    else
      @locale = nil
    end

    self
  end


  def finish_page_dir
    return unless @page_dir

    @files << @page_dir.to_s

    page_dir = @page_dir.expand_path.relative_path_from @root

    @page_dir = page_dir
  end


  def generator_descriptions
    lengths = []

    generators = RDoc::RDoc::GENERATORS.map do |name, generator|
      lengths << name.length

      description = generator::DESCRIPTION if
        generator.const_defined? :DESCRIPTION

      [name, description]
    end

    longest = lengths.max

    generators.sort.map do |name, description|
      if description then
        "  %-*s - %s" % [longest, name, description]
      else
        "  #{name}"
      end
    end.join "\n"
  end


  def parse argv
    ignore_invalid = true

    argv.insert(0, *ENV['RDOCOPT'].split) if ENV['RDOCOPT']

    opts = OptionParser.new do |opt|
      @option_parser = opt
      opt.program_name = File.basename $0
      opt.version = RDoc::VERSION
      opt.release = nil
      opt.summary_indent = ' ' * 4
      opt.banner = <<-EOF
Usage: #{opt.program_name} [options] [names...]

  Files are parsed, and the information they contain collected, before any
  output is produced. This allows cross references between all files to be
  resolved. If a name is a directory, it is traversed. If no names are
  specified, all Ruby files in the current directory (and subdirectories) are
  processed.

  How RDoc generates output depends on the output formatter being used, and on
  the options you give.

  Options can be specified via the RDOCOPT environment variable, which
  functions similar to the RUBYOPT environment variable for ruby.

    $ export RDOCOPT="--show-hash"

  will make rdoc show hashes in method links by default.  Command-line options
  always will override those in RDOCOPT.

  Available formatters:


  RDoc understands the following file formats:

      EOF

      parsers = Hash.new { |h,parser| h[parser] = [] }

      RDoc::Parser.parsers.each do |regexp, parser|
        parsers[parser.name.sub('RDoc::Parser::', '')] << regexp.source
      end

      parsers.sort.each do |parser, regexp|
        opt.banner << "  - #{parser}: #{regexp.join ', '}\n"
      end
      opt.banner << "  - TomDoc:  Only in ruby files\n"

      opt.banner << "\n  The following options are deprecated:\n\n"

      name_length = DEPRECATED.keys.sort_by { |k| k.length }.last.length

      DEPRECATED.sort_by { |k,| k }.each do |name, reason|
        opt.banner << "    %*1$2$s  %3$s\n" % [-name_length, name, reason]
      end

      opt.accept Template do |template|
        template_dir = template_dir_for template

        unless template_dir then
          $stderr.puts "could not find template #{template}"
          nil
        else
          [template, template_dir]
        end
      end

      opt.accept Directory do |directory|
        directory = File.expand_path directory

        raise OptionParser::InvalidArgument unless File.directory? directory

        directory
      end

      opt.accept Path do |path|
        path = File.expand_path path

        raise OptionParser::InvalidArgument unless File.exist? path

        path
      end

      opt.accept PathArray do |paths,|
        paths = if paths then
                  paths.split(',').map { |d| d unless d.empty? }
                end

        paths.map do |path|
          path = File.expand_path path

          raise OptionParser::InvalidArgument unless File.exist? path

          path
        end
      end

      opt.separator nil
      opt.separator "Parsing options:"
      opt.separator nil

      if Object.const_defined? :Encoding then
        opt.on("--encoding=ENCODING", "-e", Encoding.list.map { |e| e.name },
               "Specifies the output encoding.  All files",
               "read will be converted to this encoding.",
               "The default encoding is UTF-8.",
               "--encoding is preferred over --charset") do |value|
                 @encoding = Encoding.find value
                 @charset = @encoding.name # may not be valid value
               end

        opt.separator nil
      end


      opt.on("--locale=NAME",
             "Specifies the output locale.") do |value|
        @locale_name = value
      end

      opt.on("--locale-data-dir=DIR",
             "Specifies the directory where locale data live.") do |value|
        @locale_dir = value
      end

      opt.separator nil

      opt.on("--all", "-a",
             "Synonym for --visibility=private.") do |value|
        @visibility = :private
      end

      opt.separator nil

      opt.on("--exclude=PATTERN", "-x", Regexp,
             "Do not process files or directories",
             "matching PATTERN.") do |value|
        @exclude << value
      end

      opt.separator nil

      opt.on("--extension=NEW=OLD", "-E",
             "Treat files ending with .new as if they",
             "ended with .old. Using '-E cgi=rb' will",
             "cause xxx.cgi to be parsed as a Ruby file.") do |value|
        new, old = value.split(/=/, 2)

        unless new and old then
          raise OptionParser::InvalidArgument, "Invalid parameter to '-E'"
        end

        unless RDoc::Parser.alias_extension old, new then
          raise OptionParser::InvalidArgument, "Unknown extension .#{old} to -E"
        end
      end

      opt.separator nil

      opt.on("--[no-]force-update", "-U",
             "Forces rdoc to scan all sources even if",
             "newer than the flag file.") do |value|
        @force_update = value
      end

      opt.separator nil

      opt.on("--pipe", "-p",
             "Convert RDoc on stdin to HTML") do
        @pipe = true
      end

      opt.separator nil

      opt.on("--tab-width=WIDTH", "-w", Integer,
             "Set the width of tab characters.") do |value|
        raise OptionParser::InvalidArgument,
              "#{value} is an invalid tab width" if value <= 0
        @tab_width = value
      end

      opt.separator nil

      opt.on("--visibility=VISIBILITY", "-V", RDoc::VISIBILITIES + [:nodoc],
             "Minimum visibility to document a method.",
             "One of 'public', 'protected' (the default),",
             "'private' or 'nodoc' (show everything)") do |value|
        @visibility = value
      end

      opt.separator nil

      markup_formats = RDoc::Text::MARKUP_FORMAT.keys.sort

      opt.on("--markup=MARKUP", markup_formats,
             "The markup format for the named files.",
             "The default is rdoc.  Valid values are:",
             markup_formats.join(', ')) do |value|
        @markup = value
      end

      opt.separator nil

      opt.on("--root=ROOT", Directory,
             "Root of the source tree documentation",
             "will be generated for.  Set this when",
             "building documentation outside the",
             "source directory.  Default is the",
             "current directory.") do |root|
        @root = Pathname(root)
      end

      opt.separator nil

      opt.on("--page-dir=DIR", Directory,
             "Directory where guides, your FAQ or",
             "other pages not associated with a class",
             "live.  Set this when you don't store",
             "such files at your project root.",
             "NOTE: Do not use the same file name in",
             "the page dir and the root of your project") do |page_dir|
        @page_dir = Pathname(page_dir)
      end

      opt.separator nil
      opt.separator "Common generator options:"
      opt.separator nil

      opt.on("--force-output", "-O",
             "Forces rdoc to write the output files,",
             "even if the output directory exists",
             "and does not seem to have been created",
             "by rdoc.") do |value|
        @force_output = value
      end

      opt.separator nil

      generator_text = @generators.keys.map { |name| "  #{name}" }.sort

      opt.on("-f", "--fmt=FORMAT", "--format=FORMAT", @generators.keys,
             "Set the output formatter.  One of:", *generator_text) do |value|
        check_generator

        @generator_name = value.downcase
        setup_generator
      end

      opt.separator nil

      opt.on("--include=DIRECTORIES", "-i", PathArray,
             "Set (or add to) the list of directories to",
             "be searched when satisfying :include:",
             "requests. Can be used more than once.") do |value|
        @rdoc_include.concat value.map { |dir| dir.strip }
      end

      opt.separator nil

      opt.on("--[no-]coverage-report=[LEVEL]", "--[no-]dcov", "-C", Integer,
             "Prints a report on undocumented items.",
             "Does not generate files.") do |value|
        value = 0 if value.nil? # Integer converts -C to nil

        @coverage_report = value
        @force_update = true if value
      end

      opt.separator nil

      opt.on("--output=DIR", "--op", "-o",
             "Set the output directory.") do |value|
        @op_dir = value
      end

      opt.separator nil

      opt.on("-d",
             "Deprecated --diagram option.",
             "Prevents firing debug mode",
             "with legacy invocation.") do |value|
      end

      opt.separator nil
      opt.separator 'HTML generator options:'
      opt.separator nil

      opt.on("--charset=CHARSET", "-c",
             "Specifies the output HTML character-set.",
             "Use --encoding instead of --charset if",
             "available.") do |value|
        @charset = value
      end

      opt.separator nil

      opt.on("--hyperlink-all", "-A",
             "Generate hyperlinks for all words that",
             "correspond to known methods, even if they",
             "do not start with '#' or '::' (legacy",
             "behavior).") do |value|
        @hyperlink_all = value
      end

      opt.separator nil

      opt.on("--main=NAME", "-m",
             "NAME will be the initial page displayed.") do |value|
        @main_page = value
      end

      opt.separator nil

      opt.on("--[no-]line-numbers", "-N",
             "Include line numbers in the source code.",
             "By default, only the number of the first",
             "line is displayed, in a leading comment.") do |value|
        @line_numbers = value
      end

      opt.separator nil

      opt.on("--show-hash", "-H",
             "A name of the form #name in a comment is a",
             "possible hyperlink to an instance method",
             "name. When displayed, the '#' is removed",
             "unless this option is specified.") do |value|
        @show_hash = value
      end

      opt.separator nil

      opt.on("--template=NAME", "-T", Template,
             "Set the template used when generating",
             "output. The default depends on the",
             "formatter used.") do |(template, template_dir)|
        @template     = template
        @template_dir = template_dir
      end

      opt.separator nil

      opt.on("--template-stylesheets=FILES", PathArray,
             "Set (or add to) the list of files to",
             "include with the html template.") do |value|
        @template_stylesheets << value
      end

      opt.separator nil

      opt.on("--title=TITLE", "-t",
             "Set TITLE as the title for HTML output.") do |value|
        @title = value
      end

      opt.separator nil

      opt.on("--copy-files=PATH", Path,
             "Specify a file or directory to copy static",
             "files from.",
             "If a file is given it will be copied into",
             "the output dir.  If a directory is given the",
             "entire directory will be copied.",
             "You can use this multiple times") do |value|
        @static_path << value
      end

      opt.separator nil

      opt.on("--webcvs=URL", "-W",
             "Specify a URL for linking to a web frontend",
             "to CVS. If the URL contains a '\%s', the",
             "name of the current file will be",
             "substituted; if the URL doesn't contain a",
             "'\%s', the filename will be appended to it.") do |value|
        @webcvs = value
      end

      opt.separator nil
      opt.separator "ri generator options:"
      opt.separator nil

      opt.on("--ri", "-r",
             "Generate output for use by `ri`. The files",
             "are stored in the '.rdoc' directory under",
             "your home directory unless overridden by a",
             "subsequent --op parameter, so no special",
             "privileges are needed.") do |value|
        check_generator

        @generator_name = "ri"
        @op_dir ||= RDoc::RI::Paths::HOMEDIR
        setup_generator
      end

      opt.separator nil

      opt.on("--ri-site", "-R",
             "Generate output for use by `ri`. The files",
             "are stored in a site-wide directory,",
             "making them accessible to others, so",
             "special privileges are needed.") do |value|
        check_generator

        @generator_name = "ri"
        @op_dir = RDoc::RI::Paths.site_dir
        setup_generator
      end

      opt.separator nil
      opt.separator "Generic options:"
      opt.separator nil

      opt.on("--write-options",
             "Write .rdoc_options to the current",
             "directory with the given options.  Not all",
             "options will be used.  See RDoc::Options",
             "for details.") do |value|
        @write_options = true
      end

      opt.separator nil

      opt.on("--[no-]dry-run",
             "Don't write any files") do |value|
        @dry_run = value
      end

      opt.separator nil

      opt.on("-D", "--[no-]debug",
             "Displays lots on internal stuff.") do |value|
        $DEBUG_RDOC = value
      end

      opt.separator nil

      opt.on("--[no-]ignore-invalid",
             "Ignore invalid options and continue",
             "(default true).") do |value|
        ignore_invalid = value
      end

      opt.separator nil

      opt.on("--quiet", "-q",
             "Don't show progress as we parse.") do |value|
        @verbosity = 0
      end

      opt.separator nil

      opt.on("--verbose", "-V",
             "Display extra progress as RDoc parses") do |value|
        @verbosity = 2
      end

      opt.separator nil

      opt.on("--version", "-v", "print the version") do
        puts opt.version
        exit
      end

      opt.separator nil

      opt.on("--help", "-h", "Display this help") do
        RDoc::RDoc::GENERATORS.each_key do |generator|
          setup_generator generator
        end

        puts opt.help
        exit
      end

      opt.separator nil
    end

    setup_generator 'darkfish' if
      argv.grep(/\A(-f|--fmt|--format|-r|-R|--ri|--ri-site)\b/).empty?

    deprecated = []
    invalid = []

    begin
      opts.parse! argv
    rescue OptionParser::ParseError => e
      if DEPRECATED[e.args.first] then
        deprecated << e.args.first
      elsif %w[--format --ri -r --ri-site -R].include? e.args.first then
        raise
      else
        invalid << e.args.join(' ')
      end

      retry
    end

    unless @generator then
      @generator = RDoc::Generator::Darkfish
      @generator_name = 'darkfish'
    end

    if @pipe and not argv.empty? then
      @pipe = false
      invalid << '-p (with files)'
    end

    unless quiet then
      deprecated.each do |opt|
        $stderr.puts 'option ' << opt << ' is deprecated: ' << DEPRECATED[opt]
      end
    end

    unless invalid.empty? then
      invalid = "invalid options: #{invalid.join ', '}"

      if ignore_invalid then
        unless quiet then
          $stderr.puts invalid
          $stderr.puts '(invalid options are ignored)'
        end
      else
        unless quiet then
          $stderr.puts opts
        end
        $stderr.puts invalid
        exit 1
      end
    end

    @files = argv.dup

    finish

    if @write_options then
      write_options
      exit
    end

    self
  end


  def quiet
    @verbosity.zero?
  end


  def quiet= bool
    @verbosity = bool ? 0 : 1
  end


  def sanitize_path path
    require 'pathname'
    dot = Pathname.new('.').expand_path

    path.reject do |item|
      path = Pathname.new(item).expand_path
      relative = path.relative_path_from(dot).to_s
      relative.start_with? '..'
    end
  end


  def setup_generator generator_name = @generator_name
    @generator = @generators[generator_name]

    unless @generator then
      raise OptionParser::InvalidArgument,
            "Invalid output formatter #{generator_name}"
    end

    return if @generator_options.include? @generator

    @generator_name = generator_name
    @generator_options << @generator

    if @generator.respond_to? :setup_options then
      @option_parser ||= OptionParser.new
      @generator.setup_options self
    end
  end


  def template_dir_for template
    template_path = File.join 'rdoc', 'generator', 'template', template

    $LOAD_PATH.map do |path|
      File.join File.expand_path(path), template_path
    end.find do |dir|
      File.directory? dir
    end
  end


  def to_yaml opts = {} # :nodoc:
    return super if YAML.const_defined?(:ENGINE) and not YAML::ENGINE.syck?

    YAML.quick_emit self, opts do |out|
      out.map taguri, to_yaml_style do |map|
        encode_with map
      end
    end
  end


  def visibility= visibility
    case visibility
    when :all
      @visibility = :private
    else
      @visibility = visibility
    end
  end


  def warn message
    super message if @verbosity > 1
  end


  def write_options
    RDoc.load_yaml

    open '.rdoc_options', 'w' do |io|
      io.set_encoding Encoding::UTF_8 if Object.const_defined? :Encoding

      YAML.dump self, io
    end
  end

end

