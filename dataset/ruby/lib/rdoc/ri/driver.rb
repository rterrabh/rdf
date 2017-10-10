require 'abbrev'
require 'optparse'

begin
  require 'readline'
rescue LoadError
end

begin
  require 'win32console'
rescue LoadError
end

require 'rdoc'


require 'rdoc/ri/formatter'


class RDoc::RI::Driver


  class Error < RDoc::RI::Error; end


  class NotFoundError < Error


    alias name message

    def message # :nodoc:
      "Nothing known about #{super}"
    end
  end


  attr_accessor :show_all


  attr_accessor :stores


  attr_accessor :use_stdout


  def self.default_options
    options = {}
    options[:interactive] = false
    options[:profile]     = false
    options[:show_all]    = false
    options[:use_cache]   = true
    options[:use_stdout]  = !$stdout.tty?
    options[:width]       = 72

    options[:use_system]     = true
    options[:use_site]       = true
    options[:use_home]       = true
    options[:use_gems]       = true
    options[:extra_doc_dirs] = []

    return options
  end


  def self.dump data_path
    require 'pp'

    open data_path, 'rb' do |io|
      pp Marshal.load(io.read)
    end
  end


  def self.process_args argv
    options = default_options

    opts = OptionParser.new do |opt|
      opt.accept File do |file,|
        File.readable?(file) and not File.directory?(file) and file
      end

      opt.program_name = File.basename $0
      opt.version = RDoc::VERSION
      opt.release = nil
      opt.summary_indent = ' ' * 4

      opt.banner = <<-EOT
Usage: #{opt.program_name} [options] [names...]

Where name can be:

  Class | Module | Module::Class

  Class::method | Class#method | Class.method | method

  gem_name: | gem_name:README | gem_name:History

All class names may be abbreviated to their minimum unambiguous form. If a name
is ambiguous, all valid options will be listed.

A '.' matches either class or instance methods, while #method
matches only instance and ::method matches only class methods.

README and other files may be displayed by prefixing them with the gem name
they're contained in.  If the gem name is followed by a ':' all files in the
gem will be shown.  The file name extension may be omitted where it is
unambiguous.

For example:


Note that shell quoting or escaping may be required for method names containing
punctuation:


To see the default directories ri will search, run:


Specifying the --system, --site, --home, --gems or --doc-dir options will
limit ri to searching only the specified directories.

ri options may be set in the 'RI' environment variable.

The ri pager can be set with the 'RI_PAGER' environment variable or the
'PAGER' environment variable.
      EOT

      opt.separator nil
      opt.separator "Options:"

      opt.separator nil

      opt.on("--[no-]interactive", "-i",
             "In interactive mode you can repeatedly",
             "look up methods with autocomplete.") do |interactive|
        options[:interactive] = interactive
      end

      opt.separator nil

      opt.on("--[no-]all", "-a",
             "Show all documentation for a class or",
             "module.") do |show_all|
        options[:show_all] = show_all
      end

      opt.separator nil

      opt.on("--[no-]list", "-l",
             "List classes ri knows about.") do |list|
        options[:list] = list
      end

      opt.separator nil

      opt.on("--[no-]pager",
             "Send output directly to stdout,",
             "rather than to a pager.") do |use_pager|
        options[:use_stdout] = !use_pager
      end

      opt.separator nil

      opt.on("-T",
             "Synonym for --no-pager") do
        options[:use_stdout] = true
      end

      opt.separator nil

      opt.on("--width=WIDTH", "-w", OptionParser::DecimalInteger,
             "Set the width of the output.") do |width|
        options[:width] = width
      end

      opt.separator nil

      opt.on("--server [PORT]", Integer,
             "Run RDoc server on the given port.",
             "The default port is 8214.") do |port|
        options[:server] = port || 8214
      end

      opt.separator nil

      formatters = RDoc::Markup.constants.grep(/^To[A-Z][a-z]+$/).sort
      formatters = formatters.sort.map do |formatter|
        formatter.to_s.sub('To', '').downcase
      end
      formatters -= %w[html label test] # remove useless output formats

      opt.on("--format=NAME", "-f",
             "Uses the selected formatter. The default",
             "formatter is bs for paged output and ansi",
             "otherwise. Valid formatters are:",
             formatters.join(' '), formatters) do |value|
        #nodyna <const_get-2031> <CG MODERATE (array)>
        options[:formatter] = RDoc::Markup.const_get "To#{value.capitalize}"
      end

      opt.separator nil
      opt.separator "Data source options:"
      opt.separator nil

      opt.on("--[no-]list-doc-dirs",
             "List the directories from which ri will",
             "source documentation on stdout and exit.") do |list_doc_dirs|
        options[:list_doc_dirs] = list_doc_dirs
      end

      opt.separator nil

      opt.on("--doc-dir=DIRNAME", "-d", Array,
             "List of directories from which to source",
             "documentation in addition to the standard",
             "directories.  May be repeated.") do |value|
        value.each do |dir|
          unless File.directory? dir then
            raise OptionParser::InvalidArgument, "#{dir} is not a directory"
          end

          options[:extra_doc_dirs] << File.expand_path(dir)
        end
      end

      opt.separator nil

      opt.on("--no-standard-docs",
             "Do not include documentation from",
             "the Ruby standard library, site_lib,",
             "installed gems, or ~/.rdoc.",
             "Use with --doc-dir") do
        options[:use_system] = false
        options[:use_site] = false
        options[:use_gems] = false
        options[:use_home] = false
      end

      opt.separator nil

      opt.on("--[no-]system",
             "Include documentation from Ruby's standard",
             "library.  Defaults to true.") do |value|
        options[:use_system] = value
      end

      opt.separator nil

      opt.on("--[no-]site",
             "Include documentation from libraries",
             "installed in site_lib.",
             "Defaults to true.") do |value|
        options[:use_site] = value
      end

      opt.separator nil

      opt.on("--[no-]gems",
             "Include documentation from RubyGems.",
             "Defaults to true.") do |value|
        options[:use_gems] = value
      end

      opt.separator nil

      opt.on("--[no-]home",
             "Include documentation stored in ~/.rdoc.",
             "Defaults to true.") do |value|
        options[:use_home] = value
      end

      opt.separator nil
      opt.separator "Debug options:"
      opt.separator nil

      opt.on("--[no-]profile",
             "Run with the ruby profiler") do |value|
        options[:profile] = value
      end

      opt.separator nil

      opt.on("--dump=CACHE", File,
             "Dumps data from an ri cache or data file") do |value|
        options[:dump_path] = value
      end
    end

    argv = ENV['RI'].to_s.split.concat argv

    opts.parse! argv

    options[:names] = argv

    options[:use_stdout] ||= !$stdout.tty?
    options[:use_stdout] ||= options[:interactive]
    options[:width] ||= 72

    options

  rescue OptionParser::InvalidArgument, OptionParser::InvalidOption => e
    puts opts
    puts
    puts e
    exit 1
  end


  def self.run argv = ARGV
    options = process_args argv

    if options[:dump_path] then
      dump options[:dump_path]
      return
    end

    ri = new options
    ri.run
  end


  def initialize initial_options = {}
    @paging = false
    @classes = nil

    options = self.class.default_options.update(initial_options)

    @formatter_klass = options[:formatter]

    require 'profile' if options[:profile]

    @names = options[:names]
    @list = options[:list]

    @doc_dirs = []
    @stores   = []

    RDoc::RI::Paths.each(options[:use_system], options[:use_site],
                         options[:use_home], options[:use_gems],
                         *options[:extra_doc_dirs]) do |path, type|
      @doc_dirs << path

      store = RDoc::RI::Store.new path, type
      store.load_cache
      @stores << store
    end

    @list_doc_dirs = options[:list_doc_dirs]

    @interactive = options[:interactive]
    @server      = options[:server]
    @use_stdout  = options[:use_stdout]
    @show_all    = options[:show_all]

    @jruby_pager_process = nil
  end


  def add_also_in out, also_in
    return if also_in.empty?

    out << RDoc::Markup::Rule.new(1)
    out << RDoc::Markup::Paragraph.new("Also found in:")

    paths = RDoc::Markup::Verbatim.new
    also_in.each do |store|
      paths.parts.push store.friendly_path, "\n"
    end
    out << paths
  end


  def add_class out, name, classes
    heading = if classes.all? { |klass| klass.module? } then
                name
              else
                superclass = classes.map do |klass|
                  klass.superclass unless klass.module?
                end.compact.shift || 'Object'

                superclass = superclass.full_name unless String === superclass

                "#{name} < #{superclass}"
              end

    out << RDoc::Markup::Heading.new(1, heading)
    out << RDoc::Markup::BlankLine.new
  end


  def add_from out, store
    out << RDoc::Markup::Paragraph.new("(from #{store.friendly_path})")
  end


  def add_extends out, extends
    add_extension_modules out, 'Extended by', extends
  end


  def add_extension_modules out, type, extensions
    return if extensions.empty?

    out << RDoc::Markup::Rule.new(1)
    out << RDoc::Markup::Heading.new(1, "#{type}:")

    extensions.each do |modules, store|
      if modules.length == 1 then
        add_extension_modules_single out, store, modules.first
      else
        add_extension_modules_multiple out, store, modules
      end
    end
  end


  def add_extension_modules_multiple out, store, modules # :nodoc:
    out << RDoc::Markup::Paragraph.new("(from #{store.friendly_path})")

    wout, with = modules.partition { |incl| incl.comment.empty? }

    out << RDoc::Markup::BlankLine.new unless with.empty?

    with.each do |incl|
      out << RDoc::Markup::Paragraph.new(incl.name)
      out << RDoc::Markup::BlankLine.new
      out << incl.comment
    end

    unless wout.empty? then
      verb = RDoc::Markup::Verbatim.new

      wout.each do |incl|
        verb.push incl.name, "\n"
      end

      out << verb
    end
  end


  def add_extension_modules_single out, store, include # :nodoc:
    name = include.name
    path = store.friendly_path
    out << RDoc::Markup::Paragraph.new("#{name} (from #{path})")

    if include.comment then
      out << RDoc::Markup::BlankLine.new
      out << include.comment
    end
  end


  def add_includes out, includes
    add_extension_modules out, 'Includes', includes
  end


  def add_method out, name
    filtered   = lookup_method name

    method_out = method_document name, filtered

    out.concat method_out.parts
  end


  def add_method_documentation out, klass
    klass.method_list.each do |method|
      begin
        add_method out, method.full_name
      rescue NotFoundError
        next
      end
    end
  end


  def add_method_list out, methods, name
    return if methods.empty?

    out << RDoc::Markup::Heading.new(1, "#{name}:")
    out << RDoc::Markup::BlankLine.new

    if @use_stdout and !@interactive then
      out.concat methods.map { |method|
        RDoc::Markup::Verbatim.new method
      }
    else
      out << RDoc::Markup::IndentedParagraph.new(2, methods.join(', '))
    end

    out << RDoc::Markup::BlankLine.new
  end


  def ancestors_of klass
    ancestors = []

    unexamined = [klass]
    seen = []

    loop do
      break if unexamined.empty?
      current = unexamined.shift
      seen << current

      stores = classes[current]

      break unless stores and not stores.empty?

      klasses = stores.map do |store|
        store.ancestors[current]
      end.flatten.uniq

      klasses = klasses - seen

      ancestors.concat klasses
      unexamined.concat klasses
    end

    ancestors.reverse
  end


  def class_cache # :nodoc:
  end


  def class_document name, found, klasses, includes, extends
    also_in = []

    out = RDoc::Markup::Document.new

    add_class out, name, klasses

    add_includes out, includes
    add_extends  out, extends

    found.each do |store, klass|
      render_class out, store, klass, also_in
    end

    add_also_in out, also_in

    out
  end


  def class_document_comment out, comment # :nodoc:
    unless comment.empty? then
      out << RDoc::Markup::Rule.new(1)

      if comment.merged? then
        parts = comment.parts
        parts = parts.zip [RDoc::Markup::BlankLine.new] * parts.length
        parts.flatten!
        parts.pop

        out.concat parts
      else
        out << comment
      end
    end
  end


  def class_document_constants out, klass # :nodoc:
    return if klass.constants.empty?

    out << RDoc::Markup::Heading.new(1, "Constants:")
    out << RDoc::Markup::BlankLine.new
    list = RDoc::Markup::List.new :NOTE

    constants = klass.constants.sort_by { |constant| constant.name }

    list.items.concat constants.map { |constant|
      parts = constant.comment.parts if constant.comment
      parts << RDoc::Markup::Paragraph.new('[not documented]') if
        parts.empty?

      RDoc::Markup::ListItem.new(constant.name, *parts)
    }

    out << list
    out << RDoc::Markup::BlankLine.new
  end


  def classes
    return @classes if @classes

    @classes = {}

    @stores.each do |store|
      store.cache[:modules].each do |mod|
        @classes[mod] ||= []
        @classes[mod] << store
      end
    end

    @classes
  end


  def classes_and_includes_and_extends_for name
    klasses = []
    extends = []
    includes = []

    found = @stores.map do |store|
      begin
        klass = store.load_class name
        klasses  << klass
        extends  << [klass.extends,  store] if klass.extends
        includes << [klass.includes, store] if klass.includes
        [store, klass]
      rescue RDoc::Store::MissingFileError
      end
    end.compact

    extends.reject!  do |modules,| modules.empty? end
    includes.reject! do |modules,| modules.empty? end

    [found, klasses, includes, extends]
  end


  def complete name
    completions = []

    klass, selector, method = parse_name name

    complete_klass  name, klass, selector, method, completions
    complete_method name, klass, selector,         completions

    completions.sort.uniq
  end

  def complete_klass name, klass, selector, method, completions # :nodoc:
    klasses = classes.keys

    klass_name = method ? name : klass

    if name !~ /#|\./ then
      completions.replace klasses.grep(/^#{Regexp.escape klass_name}[^:]*$/)
      completions.concat klasses.grep(/^#{Regexp.escape name}[^:]*$/) if
        name =~ /::$/

      completions << klass if classes.key? klass # to complete a method name
    elsif selector then
      completions << klass if classes.key? klass
    elsif classes.key? klass_name then
      completions << klass_name
    end
  end

  def complete_method name, klass, selector, completions # :nodoc:
    if completions.include? klass and name =~ /#|\.|::/ then
      methods = list_methods_matching name

      if not methods.empty? then
        completions.delete klass
      elsif selector then
        completions.delete klass
        completions << "#{klass}#{selector}"
      end

      completions.concat methods
    end
  end


  def display document
    page do |io|
      text = document.accept formatter(io)

      io.write text
    end
  end


  def display_class name
    return if name =~ /#|\./

    found, klasses, includes, extends =
      classes_and_includes_and_extends_for name

    return if found.empty?

    out = class_document name, found, klasses, includes, extends

    display out
  end


  def display_method name
    out = RDoc::Markup::Document.new

    add_method out, name

    display out
  end


  def display_name name
    if name =~ /\w:(\w|$)/ then
      display_page name
      return true
    end

    return true if display_class name

    display_method name if name =~ /::|#|\./

    true
  rescue NotFoundError
    matches = list_methods_matching name if name =~ /::|#|\./
    matches = classes.keys.grep(/^#{Regexp.escape name}/) if matches.empty?

    raise if matches.empty?

    page do |io|
      io.puts "#{name} not found, maybe you meant:"
      io.puts
      io.puts matches.sort.join("\n")
    end

    false
  end


  def display_names names
    names.each do |name|
      name = expand_name name

      display_name name
    end
  end


  def display_page name
    store_name, page_name = name.split ':', 2

    store = @stores.find { |s| s.source == store_name }

    return display_page_list store if page_name.empty?

    pages = store.cache[:pages]

    unless pages.include? page_name then
      found_names = pages.select do |n|
        n =~ /#{Regexp.escape page_name}\.[^.]+$/
      end

      if found_names.length.zero? then
        return display_page_list store, pages
      elsif found_names.length > 1 then
        return display_page_list store, found_names, page_name
      end

      page_name = found_names.first
    end

    page = store.load_page page_name

    display page.comment
  end


  def display_page_list store, pages = store.cache[:pages], search = nil
    out = RDoc::Markup::Document.new

    title = if search then
              "#{search} pages"
            else
              'Pages'
            end

    out << RDoc::Markup::Heading.new(1, "#{title} in #{store.friendly_path}")
    out << RDoc::Markup::BlankLine.new

    list = RDoc::Markup::List.new(:BULLET)

    pages.each do |page|
      list << RDoc::Markup::Paragraph.new(page)
    end

    out << list

    display out
  end


  def expand_class klass
    klass.split('::').inject '' do |expanded, klass_part|
      expanded << '::' unless expanded.empty?
      short = expanded << klass_part

      subset = classes.keys.select do |klass_name|
        klass_name =~ /^#{expanded}[^:]*$/
      end

      abbrevs = Abbrev.abbrev subset

      expanded = abbrevs[short]

      raise NotFoundError, short unless expanded

      expanded.dup
    end
  end


  def expand_name name
    klass, selector, method = parse_name name

    return [selector, method].join if klass.empty?

    case selector
    when ':' then
      [find_store(klass),   selector, method]
    else
      [expand_class(klass), selector, method]
    end.join
  end


  def filter_methods found, name
    regexp = name_regexp name

    filtered = found.find_all do |store, methods|
      methods.any? { |method| method.full_name =~ regexp }
    end

    return filtered unless filtered.empty?

    found
  end


  def find_methods name
    klass, selector, method = parse_name name

    types = method_type selector

    klasses = nil
    ambiguous = klass.empty?

    if ambiguous then
      klasses = classes.keys
    else
      klasses = ancestors_of klass
      klasses.unshift klass
    end

    methods = []

    klasses.each do |ancestor|
      ancestors = classes[ancestor]

      next unless ancestors

      klass = ancestor if ambiguous

      ancestors.each do |store|
        methods << [store, klass, ancestor, types, method]
      end
    end

    methods = methods.sort_by do |_, k, a, _, m|
      [k, a, m].compact
    end

    methods.each do |item|
      yield(*item) # :yields: store, klass, ancestor, types, method
    end

    self
  end


  def find_pager_jruby pager
    require 'java'
    require 'shellwords'

    return nil unless java.lang.ProcessBuilder.constants.include? :Redirect

    pager = Shellwords.split pager

    pb = java.lang.ProcessBuilder.new(*pager)
    pb = pb.redirect_output java.lang.ProcessBuilder::Redirect::INHERIT

    @jruby_pager_process = pb.start

    input = @jruby_pager_process.output_stream

    io = input.to_io
    io.sync = true
    io
  rescue java.io.IOException
    false
  end


  def find_store name
    @stores.each do |store|
      source = store.source

      return source if source == name

      return source if
        store.type == :gem and source =~ /^#{Regexp.escape name}-\d/
    end

    raise RDoc::RI::Driver::NotFoundError, name
  end


  def formatter(io)
    if @formatter_klass then
      @formatter_klass.new
    elsif paging? or !io.tty? then
      RDoc::Markup::ToBs.new
    else
      RDoc::Markup::ToAnsi.new
    end
  end


  def interactive
    puts "\nEnter the method name you want to look up."

    if defined? Readline then
      Readline.completion_proc = method :complete
      puts "You can use tab to autocomplete."
    end

    puts "Enter a blank line to exit.\n\n"

    loop do
      name = if defined? Readline then
               Readline.readline ">> "
             else
               print ">> "
               $stdin.gets
             end

      return if name.nil? or name.empty?

      name = expand_name name.strip

      begin
        display_name name
      rescue NotFoundError => e
        puts e.message
      end
    end

  rescue Interrupt
    exit
  end


  def in_path? file
    return true if file =~ %r%\A/% and File.exist? file

    ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
      File.exist? File.join(path, file)
    end
  end


  def list_known_classes names = []
    classes = []

    stores.each do |store|
      classes << store.module_names
    end

    classes = classes.flatten.uniq.sort

    unless names.empty? then
      filter = Regexp.union names.map { |name| /^#{name}/ }

      classes = classes.grep filter
    end

    page do |io|
      if paging? or io.tty? then
        if names.empty? then
          io.puts "Classes and Modules known to ri:"
        else
          io.puts "Classes and Modules starting with #{names.join ', '}:"
        end
        io.puts
      end

      io.puts classes.join("\n")
    end
  end


  def list_methods_matching name
    found = []

    find_methods name do |store, klass, ancestor, types, method|
      if types == :instance or types == :both then
        methods = store.instance_methods[ancestor]

        if methods then
          matches = methods.grep(/^#{Regexp.escape method.to_s}/)

          matches = matches.map do |match|
            "#{klass}##{match}"
          end

          found.concat matches
        end
      end

      if types == :class or types == :both then
        methods = store.class_methods[ancestor]

        next unless methods
        matches = methods.grep(/^#{Regexp.escape method.to_s}/)

        matches = matches.map do |match|
          "#{klass}::#{match}"
        end

        found.concat matches
      end
    end

    found.uniq
  end


  def load_method store, cache, klass, type, name
    #nodyna <send-2032> <not yet classified>
    methods = store.send(cache)[klass]

    return unless methods

    method = methods.find do |method_name|
      method_name == name
    end

    return unless method

    store.load_method klass, "#{type}#{method}"
  rescue RDoc::Store::MissingFileError => e
    comment = RDoc::Comment.new("missing documentation at #{e.file}").parse

    method = RDoc::AnyMethod.new nil, name
    method.comment = comment
    method
  end


  def load_methods_matching name
    found = []

    find_methods name do |store, klass, ancestor, types, method|
      methods = []

      methods << load_method(store, :class_methods, ancestor, '::',  method) if
        [:class, :both].include? types

      methods << load_method(store, :instance_methods, ancestor, '#',  method) if
        [:instance, :both].include? types

      found << [store, methods.compact]
    end

    found.reject do |path, methods| methods.empty? end
  end


  def lookup_method name
    found = load_methods_matching name

    raise NotFoundError, name if found.empty?

    filter_methods found, name
  end


  def method_document name, filtered
    out = RDoc::Markup::Document.new

    out << RDoc::Markup::Heading.new(1, name)
    out << RDoc::Markup::BlankLine.new

    filtered.each do |store, methods|
      methods.each do |method|
        render_method out, store, method, name
      end
    end

    out
  end


  def method_type selector
    case selector
    when '.', nil then :both
    when '#'      then :instance
    else               :class
    end
  end


  def name_regexp name
    klass, type, name = parse_name name

    case type
    when '#', '::' then
      /^#{klass}#{type}#{Regexp.escape name}$/
    else
      /^#{klass}(#|::)#{Regexp.escape name}$/
    end
  end


  def page
    if pager = setup_pager then
      begin
        yield pager
      ensure
        pager.close
        @jruby_pager_process.wait_for if @jruby_pager_process
      end
    else
      yield $stdout
    end
  rescue Errno::EPIPE
  ensure
    @paging = false
  end


  def paging?
    @paging
  end


  def parse_name name
    parts = name.split(/(::?|#|\.)/)

    if parts.length == 1 then
      if parts.first =~ /^[a-z]|^([%&*+\/<>^`|~-]|\+@|-@|<<|<=>?|===?|=>|=~|>>|\[\]=?|~@)$/ then
        type = '.'
        meth = parts.pop
      else
        type = nil
        meth = nil
      end
    elsif parts.length == 2 or parts.last =~ /::|#|\./ then
      type = parts.pop
      meth = nil
    elsif parts[1] == ':' then
      klass = parts.shift
      type  = parts.shift
      meth  = parts.join
    elsif parts[-2] != '::' or parts.last !~ /^[A-Z]/ then
      meth = parts.pop
      type = parts.pop
    end

    klass ||= parts.join

    [klass, type, meth]
  end


  def render_class out, store, klass, also_in # :nodoc:
    comment = klass.comment
    class_methods    = store.class_methods[klass.full_name]    || []
    instance_methods = store.instance_methods[klass.full_name] || []
    attributes       = store.attributes[klass.full_name]       || []

    if comment.empty? and
       instance_methods.empty? and class_methods.empty? then
      also_in << store
      return
    end

    add_from out, store

    class_document_comment out, comment

    if class_methods or instance_methods or not klass.constants.empty? then
      out << RDoc::Markup::Rule.new(1)
    end

    class_document_constants out, klass

    add_method_list out, class_methods,    'Class methods'
    add_method_list out, instance_methods, 'Instance methods'
    add_method_list out, attributes,       'Attributes'

    add_method_documentation out, klass if @show_all
  end

  def render_method out, store, method, name # :nodoc:
    out << RDoc::Markup::Paragraph.new("(from #{store.friendly_path})")

    unless name =~ /^#{Regexp.escape method.parent_name}/ then
      out << RDoc::Markup::Heading.new(3, "Implementation from #{method.parent_name}")
    end

    out << RDoc::Markup::Rule.new(1)

    render_method_arguments out, method.arglists
    render_method_superclass out, method
    render_method_comment out, method
  end

  def render_method_arguments out, arglists # :nodoc:
    return unless arglists

    arglists = arglists.chomp.split "\n"
    arglists = arglists.map { |line| line + "\n" }
    out << RDoc::Markup::Verbatim.new(*arglists)
    out << RDoc::Markup::Rule.new(1)
  end

  def render_method_comment out, method # :nodoc:
    out << RDoc::Markup::BlankLine.new
    out << method.comment
    out << RDoc::Markup::BlankLine.new
  end

  def render_method_superclass out, method # :nodoc:
    return unless
      method.respond_to?(:superclass_method) and method.superclass_method

    out << RDoc::Markup::BlankLine.new
    out << RDoc::Markup::Heading.new(4, "(Uses superclass method #{method.superclass_method})")
    out << RDoc::Markup::Rule.new(1)
  end


  def run
    if @list_doc_dirs then
      puts @doc_dirs
    elsif @list then
      list_known_classes @names
    elsif @server then
      start_server
    elsif @interactive or @names.empty? then
      interactive
    else
      display_names @names
    end
  rescue NotFoundError => e
    abort e.message
  end


  def setup_pager
    return if @use_stdout

    jruby = Object.const_defined?(:RUBY_ENGINE) && RUBY_ENGINE == 'jruby'

    pagers = [ENV['RI_PAGER'], ENV['PAGER'], 'pager', 'less', 'more']

    pagers.compact.uniq.each do |pager|
      next unless pager

      pager_cmd = pager.split.first

      next unless in_path? pager_cmd

      if jruby then
        case io = find_pager_jruby(pager)
        when nil   then break
        when false then next
        else            io
        end
      else
        io = IO.popen(pager, 'w') rescue next
      end

      next if $? and $?.pid == io.pid and $?.exited? # pager didn't work

      @paging = true

      return io
    end

    @use_stdout = true

    nil
  end


  def start_server
    require 'webrick'

    server = WEBrick::HTTPServer.new :Port => @server

    extra_doc_dirs = @stores.map {|s| s.type == :extra ? s.path : nil}.compact

    server.mount '/', RDoc::Servlet, nil, extra_doc_dirs

    trap 'INT'  do server.shutdown end
    trap 'TERM' do server.shutdown end

    server.start
  end

end

