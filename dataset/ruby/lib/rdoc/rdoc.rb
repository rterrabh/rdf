require 'rdoc'

require 'find'
require 'fileutils'
require 'pathname'
require 'time'


class RDoc::RDoc

  @current = nil


  GENERATORS = {}


  attr_accessor :exclude


  attr_accessor :generator


  attr_reader :last_modified


  attr_accessor :options


  attr_reader :stats


  attr_reader :store


  def self.add_generator(klass)
    name = klass.name.sub(/^RDoc::Generator::/, '').downcase
    GENERATORS[name] = klass
  end


  def self.current
    @current
  end


  def self.current= rdoc
    @current = rdoc
  end


  def initialize
    @current       = nil
    @exclude       = nil
    @generator     = nil
    @last_modified = {}
    @old_siginfo   = nil
    @options       = nil
    @stats         = nil
    @store         = nil
  end


  def error(msg)
    raise RDoc::Error, msg
  end


  def gather_files files
    files = ["."] if files.empty?

    file_list = normalized_file_list files, true, @exclude

    file_list = file_list.uniq

    file_list = remove_unparseable file_list

    file_list.sort
  end


  def handle_pipe
    @html = RDoc::Markup::ToHtml.new @options

    parser = RDoc::Text::MARKUP_FORMAT[@options.markup]

    document = parser.parse $stdin.read

    out = @html.convert document

    $stdout.write out
  end


  def install_siginfo_handler
    return unless Signal.list.include? 'INFO'

    @old_siginfo = trap 'INFO' do
      puts @current if @current
    end
  end


  def load_options
    options_file = File.expand_path '.rdoc_options'
    return RDoc::Options.new unless File.exist? options_file

    RDoc.load_yaml

    parse_error = if Object.const_defined? :Psych then
                    Psych::SyntaxError
                  else
                    ArgumentError
                  end

    begin
      options = YAML.load_file '.rdoc_options'
    rescue *parse_error
    end

    raise RDoc::Error, "#{options_file} is not a valid rdoc options file" unless
      RDoc::Options === options

    options
  end


  def setup_output_dir(dir, force)
    flag_file = output_flag_file dir

    last = {}

    if @options.dry_run then
    elsif File.exist? dir then
      error "#{dir} exists and is not a directory" unless File.directory? dir

      begin
        open flag_file do |io|
          unless force then
            Time.parse io.gets

            io.each do |line|
              file, time = line.split "\t", 2
              time = Time.parse(time) rescue next
              last[file] = time
            end
          end
        end
      rescue SystemCallError, TypeError
        error <<-ERROR

Directory #{dir} already exists, but it looks like it isn't an RDoc directory.

Because RDoc doesn't want to risk destroying any of your existing files,
you'll need to specify a different output directory name (using the --op <dir>
option)

        ERROR
      end unless @options.force_output
    else
      FileUtils.mkdir_p dir
      FileUtils.touch flag_file
    end

    last
  end


  def store= store
    @store = store
    @store.rdoc = self
  end


  def update_output_dir(op_dir, time, last = {})
    return if @options.dry_run or not @options.update_output_dir

    open output_flag_file(op_dir), "w" do |f|
      f.puts time.rfc2822
      last.each do |n, t|
        f.puts "#{n}\t#{t.rfc2822}"
      end
    end
  end


  def output_flag_file(op_dir)
    File.join op_dir, "created.rid"
  end


  def parse_dot_doc_file in_dir, filename
    patterns = File.read(filename).gsub(/#.*/, '')

    result = []

    patterns.split.each do |patt|
      candidates = Dir.glob(File.join(in_dir, patt))
      result.concat normalized_file_list(candidates)
    end

    result
  end


  def normalized_file_list(relative_files, force_doc = false,
                           exclude_pattern = nil)
    file_list = []

    relative_files.each do |rel_file_name|
      next if rel_file_name.end_with? 'created.rid'
      next if exclude_pattern && exclude_pattern =~ rel_file_name
      stat = File.stat rel_file_name rescue next

      case type = stat.ftype
      when "file" then
        next if last_modified = @last_modified[rel_file_name] and
                stat.mtime.to_i <= last_modified.to_i

        if force_doc or RDoc::Parser.can_parse(rel_file_name) then
          file_list << rel_file_name.sub(/^\.\//, '')
          @last_modified[rel_file_name] = stat.mtime
        end
      when "directory" then
        next if rel_file_name == "CVS" || rel_file_name == ".svn"

        created_rid = File.join rel_file_name, "created.rid"
        next if File.file? created_rid

        dot_doc = File.join rel_file_name, RDoc::DOT_DOC_FILENAME

        if File.file? dot_doc then
          file_list << parse_dot_doc_file(rel_file_name, dot_doc)
        else
          file_list << list_files_in_directory(rel_file_name)
        end
      else
        warn "rdoc can't parse the #{type} #{rel_file_name}"
      end
    end

    file_list.flatten
  end


  def list_files_in_directory dir
    files = Dir.glob File.join(dir, "*")

    normalized_file_list files, false, @options.exclude
  end


  def parse_file filename
    if Object.const_defined? :Encoding then
      encoding = @options.encoding
      filename = filename.encode encoding
    end

    @stats.add_file filename

    return if RDoc::Parser.binary? filename

    content = RDoc::Encoding.read_file filename, encoding

    return unless content

    filename_path = Pathname(filename).expand_path
    relative_path = filename_path.relative_path_from @options.root

    if @options.page_dir and
       relative_path.to_s.start_with? @options.page_dir.to_s then
      relative_path =
        relative_path.relative_path_from @options.page_dir
    end

    top_level = @store.add_file filename, relative_path.to_s

    parser = RDoc::Parser.for top_level, filename, content, @options, @stats

    return unless parser

    parser.scan

    top_level.classes_or_modules.each do |cm|
      cm.done_documenting = false
    end

    top_level

  rescue Errno::EACCES => e
    $stderr.puts <<-EOF
Unable to read #{filename}, #{e.message}

Please check the permissions for this file.  Perhaps you do not have access to
it or perhaps the original author's permissions are to restrictive.  If the
this is not your library please report a bug to the author.
    EOF
  rescue => e
    $stderr.puts <<-EOF
Before reporting this, could you check that the file you're documenting
has proper syntax:


RDoc is not a full Ruby parser and will fail when fed invalid ruby programs.

The internal error was:

\t(#{e.class}) #{e.message}

    EOF

    $stderr.puts e.backtrace.join("\n\t") if $DEBUG_RDOC

    raise e
    nil
  end


  def parse_files files
    file_list = gather_files files
    @stats = RDoc::Stats.new @store, file_list.length, @options.verbosity

    return [] if file_list.empty?

    @stats.begin_adding

    file_info = file_list.map do |filename|
      @current = filename
      parse_file filename
    end.compact

    @stats.done_adding

    file_info
  end


  def remove_unparseable files
    files.reject do |file|
      file =~ /\.(?:class|eps|erb|scpt\.txt|ttf|yml)$/i or
        (file =~ /tags$/i and
         open(file, 'rb') { |io|
           io.read(100) =~ /\A(\f\n[^,]+,\d+$|!_TAG_)/
         })
    end
  end


  def document options
    self.store = RDoc::Store.new

    if RDoc::Options === options then
      @options = options
      @options.finish
    else
      @options = load_options
      @options.parse options
    end

    if @options.pipe then
      handle_pipe
      exit
    end

    @exclude = @options.exclude

    unless @options.coverage_report then
      @last_modified = setup_output_dir @options.op_dir, @options.force_update
    end

    @store.encoding = @options.encoding if @options.respond_to? :encoding
    @store.dry_run  = @options.dry_run
    @store.main     = @options.main_page
    @store.title    = @options.title
    @store.path     = @options.op_dir

    @start_time = Time.now

    @store.load_cache

    file_info = parse_files @options.files

    @options.default_title = "RDoc Documentation"

    @store.complete @options.visibility

    @stats.coverage_level = @options.coverage_report

    if @options.coverage_report then
      puts

      puts @stats.report.accept RDoc::Markup::ToRdoc.new
    elsif file_info.empty? then
      $stderr.puts "\nNo newer files." unless @options.quiet
    else
      gen_klass = @options.generator

      @generator = gen_klass.new @store, @options

      generate
    end

    if @stats and (@options.coverage_report or not @options.quiet) then
      puts
      puts @stats.summary.accept RDoc::Markup::ToRdoc.new
    end

    exit @stats.fully_documented? if @options.coverage_report
  end


  def generate
    Dir.chdir @options.op_dir do
      unless @options.quiet then
        $stderr.puts "\nGenerating #{@generator.class.name.sub(/^.*::/, '')} format into #{Dir.pwd}..."
      end

      @generator.generate
      update_output_dir '.', @start_time, @last_modified
    end
  end


  def remove_siginfo_handler
    return unless Signal.list.key? 'INFO'

    handler = @old_siginfo || 'DEFAULT'

    trap 'INFO', handler
  end

end

begin
  require 'rubygems'

  if Gem.respond_to? :find_files then
    rdoc_extensions = Gem.find_files 'rdoc/discover'

    rdoc_extensions.each do |extension|
      begin
        load extension
      rescue => e
        warn "error loading #{extension.inspect}: #{e.message} (#{e.class})"
        warn "\t#{e.backtrace.join "\n\t"}" if $DEBUG
      end
    end
  end
rescue LoadError
end

require 'rdoc/generator/darkfish'
require 'rdoc/generator/ri'
require 'rdoc/generator/pot'

