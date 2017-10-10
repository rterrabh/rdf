
require 'erb'
require 'fileutils'
require 'pathname'
require 'rdoc/generator/markup'


class RDoc::Generator::Darkfish

  RDoc::RDoc.add_generator self

  include ERB::Util


  BUILTIN_STYLE_ITEMS = # :nodoc:
    %w[
      css/fonts.css
      fonts/Lato-Light.ttf
      fonts/Lato-LightItalic.ttf
      fonts/Lato-Regular.ttf
      fonts/Lato-RegularItalic.ttf
      fonts/SourceCodePro-Bold.ttf
      fonts/SourceCodePro-Regular.ttf
      css/rdoc.css
  ]


  GENERATOR_DIR = File.join 'rdoc', 'generator'


  VERSION = '3'


  DESCRIPTION = 'HTML generator, written by Michael Granger'


  attr_accessor :asset_rel_path


  attr_reader :base_dir


  attr_reader :classes


  attr_accessor :dry_run


  attr_accessor :file_output


  attr_reader :files


  attr_reader :json_index


  attr_reader :methods


  attr_reader :modsort


  attr_reader :store


  attr_reader :template_dir # :nodoc:


  attr_reader :outputdir


  def initialize store, options
    @store   = store
    @options = options

    @asset_rel_path = ''
    @base_dir       = Pathname.pwd.expand_path
    @dry_run        = @options.dry_run
    @file_output    = true
    @template_dir   = Pathname.new options.template_dir
    @template_cache = {}

    @classes = nil
    @context = nil
    @files   = nil
    @methods = nil
    @modsort = nil

    @json_index = RDoc::Generator::JsonIndex.new self, options
  end


  def debug_msg *msg
    return unless $DEBUG_RDOC
    $stderr.puts(*msg)
  end


  def class_dir
    nil
  end


  def file_dir
    nil
  end


  def gen_sub_directories
    @outputdir.mkpath
  end


  def write_style_sheet
    debug_msg "Copying static files"
    options = { :verbose => $DEBUG_RDOC, :noop => @dry_run }

    BUILTIN_STYLE_ITEMS.each do |item|
      install_rdoc_static_file @template_dir + item, "./#{item}", options
    end

    @options.template_stylesheets.each do |stylesheet|
      FileUtils.cp stylesheet, '.', options
    end

    Dir[(@template_dir + "{js,images}/**/*").to_s].each do |path|
      next if File.directory? path
      next if File.basename(path) =~ /^\./

      dst = Pathname.new(path).relative_path_from @template_dir

      install_rdoc_static_file @template_dir + path, dst, options
    end
  end


  def generate
    setup

    write_style_sheet
    generate_index
    generate_class_files
    generate_file_files
    generate_table_of_contents
    @json_index.generate
    @json_index.generate_gzipped

    copy_static

  rescue => e
    debug_msg "%s: %s\n  %s" % [
      e.class.name, e.message, e.backtrace.join("\n  ")
    ]

    raise
  end


  def copy_static
    return if @options.static_path.empty?

    fu_options = { :verbose => $DEBUG_RDOC, :noop => @dry_run }

    @options.static_path.each do |path|
      unless File.directory? path then
        FileUtils.install path, @outputdir, fu_options.merge(:mode => 0644)
        next
      end

      Dir.chdir path do
        Dir[File.join('**', '*')].each do |entry|
          dest_file = @outputdir + entry

          if File.directory? entry then
            FileUtils.mkdir_p entry, fu_options
          else
            FileUtils.install entry, dest_file, fu_options.merge(:mode => 0644)
          end
        end
      end
    end
  end


  def get_sorted_module_list classes
    classes.select do |klass|
      klass.display?
    end.sort
  end


  def generate_index
    setup

    template_file = @template_dir + 'index.rhtml'
    return unless template_file.exist?

    debug_msg "Rendering the index page..."

    out_file = @base_dir + @options.op_dir + 'index.html'
    rel_prefix = @outputdir.relative_path_from out_file.dirname
    search_index_rel_prefix = rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    asset_rel_prefix = asset_rel_prefix = rel_prefix + @asset_rel_path

    @title = @options.title

    render_template template_file, out_file do |io| binding end
  rescue => e
    error = RDoc::Error.new \
      "error generating index.html: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end


  def generate_class klass, template_file = nil
    setup

    current = klass

    template_file ||= @template_dir + 'class.rhtml'

    debug_msg "  working on %s (%s)" % [klass.full_name, klass.path]
    out_file   = @outputdir + klass.path
    rel_prefix = @outputdir.relative_path_from out_file.dirname
    search_index_rel_prefix = rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    asset_rel_prefix = asset_rel_prefix = rel_prefix + @asset_rel_path
    svninfo          = svninfo          = get_svninfo(current)

    @title = "#{klass.type} #{klass.full_name} - #{@options.title}"

    debug_msg "  rendering #{out_file}"
    render_template template_file, out_file do |io| binding end
  end


  def generate_class_files
    setup

    template_file = @template_dir + 'class.rhtml'
    template_file = @template_dir + 'classpage.rhtml' unless
      template_file.exist?
    return unless template_file.exist?
    debug_msg "Generating class documentation in #{@outputdir}"

    current = nil

    @classes.each do |klass|
      current = klass

      generate_class klass, template_file
    end
  rescue => e
    error = RDoc::Error.new \
      "error generating #{current.path}: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end


  def generate_file_files
    setup

    page_file     = @template_dir + 'page.rhtml'
    fileinfo_file = @template_dir + 'fileinfo.rhtml'

    filepage_file = @template_dir + 'filepage.rhtml' unless
      page_file.exist? or fileinfo_file.exist?

    return unless
      page_file.exist? or fileinfo_file.exist? or filepage_file.exist?

    debug_msg "Generating file documentation in #{@outputdir}"

    out_file = nil
    current = nil

    @files.each do |file|
      current = file

      if file.text? and page_file.exist? then
        generate_page file
        next
      end

      template_file = nil
      out_file = @outputdir + file.path
      debug_msg "  working on %s (%s)" % [file.full_name, out_file]
      rel_prefix = @outputdir.relative_path_from out_file.dirname
      search_index_rel_prefix = rel_prefix
      search_index_rel_prefix += @asset_rel_path if @file_output

      asset_rel_prefix = asset_rel_prefix = rel_prefix + @asset_rel_path

      unless filepage_file then
        if file.text? then
          next unless page_file.exist?
          template_file = page_file
          @title = file.page_name
        else
          next unless fileinfo_file.exist?
          template_file = fileinfo_file
          @title = "File: #{file.base_name}"
        end
      end

      @title += " - #{@options.title}"
      template_file ||= filepage_file

      render_template template_file, out_file do |io| binding end
    end
  rescue => e
    error =
      RDoc::Error.new "error generating #{out_file}: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end


  def generate_page file
    setup

    template_file = @template_dir + 'page.rhtml'

    out_file = @outputdir + file.path
    debug_msg "  working on %s (%s)" % [file.full_name, out_file]
    rel_prefix = @outputdir.relative_path_from out_file.dirname
    search_index_rel_prefix = rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    current          = current          = file
    asset_rel_prefix = asset_rel_prefix = rel_prefix + @asset_rel_path

    @title = "#{file.page_name} - #{@options.title}"

    debug_msg "  rendering #{out_file}"
    render_template template_file, out_file do |io| binding end
  end


  def generate_servlet_not_found message
    setup

    template_file = @template_dir + 'servlet_not_found.rhtml'
    return unless template_file.exist?

    debug_msg "Rendering the servlet 404 Not Found page..."

    rel_prefix = rel_prefix = ''
    search_index_rel_prefix = rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    asset_rel_prefix = asset_rel_prefix = ''

    @title = 'Not Found'

    render_template template_file do |io| binding end
  rescue => e
    error = RDoc::Error.new \
      "error generating servlet_not_found: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end


  def generate_servlet_root installed
    setup

    template_file = @template_dir + 'servlet_root.rhtml'
    return unless template_file.exist?

    debug_msg 'Rendering the servlet root page...'

    rel_prefix = '.'
    asset_rel_prefix = rel_prefix
    search_index_rel_prefix = asset_rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    @title = 'Local RDoc Documentation'

    render_template template_file do |io| binding end
  rescue => e
    error = RDoc::Error.new \
      "error generating servlet_root: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end


  def generate_table_of_contents
    setup

    template_file = @template_dir + 'table_of_contents.rhtml'
    return unless template_file.exist?

    debug_msg "Rendering the Table of Contents..."

    out_file = @outputdir + 'table_of_contents.html'
    rel_prefix = @outputdir.relative_path_from out_file.dirname
    search_index_rel_prefix = rel_prefix
    search_index_rel_prefix += @asset_rel_path if @file_output

    asset_rel_prefix = asset_rel_prefix = rel_prefix + @asset_rel_path

    @title = "Table of Contents - #{@options.title}"

    render_template template_file, out_file do |io| binding end
  rescue => e
    error = RDoc::Error.new \
      "error generating table_of_contents.html: #{e.message} (#{e.class})"
    error.set_backtrace e.backtrace

    raise error
  end

  def install_rdoc_static_file source, destination, options # :nodoc:
    return unless source.exist?

    begin
      FileUtils.mkdir_p File.dirname(destination), options

      begin
        FileUtils.ln source, destination, options
      rescue Errno::EEXIST
        FileUtils.rm destination
        retry
      end
    rescue
      FileUtils.cp source, destination, options
    end
  end


  def setup
    return if instance_variable_defined? :@outputdir

    @outputdir = Pathname.new(@options.op_dir).expand_path @base_dir

    return unless @store

    @classes = @store.all_classes_and_modules.sort
    @files   = @store.all_files.sort
    @methods = @classes.map { |m| m.method_list }.flatten.sort
    @modsort = get_sorted_module_list @classes
  end


  def time_delta_string seconds
    return 'less than a minute'          if seconds < 60
    return "#{seconds / 60} minute#{seconds / 60 == 1 ? '' : 's'}" if
                                            seconds < 3000     # 50 minutes
    return 'about one hour'              if seconds < 5400     # 90 minutes
    return "#{seconds / 3600} hours"     if seconds < 64800    # 18 hours
    return 'one day'                     if seconds < 86400    #  1 day
    return 'about one day'               if seconds < 172800   #  2 days
    return "#{seconds / 86400} days"     if seconds < 604800   #  1 week
    return 'about one week'              if seconds < 1209600  #  2 week
    return "#{seconds / 604800} weeks"   if seconds < 7257600  #  3 months
    return "#{seconds / 2419200} months" if seconds < 31536000 #  1 year
    return "#{seconds / 31536000} years"
  end

  SVNID_PATTERN = /
    \$Id:\s
    (\S+)\s                # filename
    (\d+)\s                # rev
    (\d{4}-\d{2}-\d{2})\s  # Date (YYYY-MM-DD)
    (\d{2}:\d{2}:\d{2}Z)\s # Time (HH:MM:SSZ)
    (\w+)\s                # committer
    \$$
  /x


  def get_svninfo klass
    constants = klass.constants or return {}

    constants.find { |c| c.value =~ SVNID_PATTERN } or return {}

    filename, rev, date, time, committer = $~.captures
    commitdate = Time.parse "#{date} #{time}"

    return {
      :filename    => filename,
      :rev         => Integer(rev),
      :commitdate  => commitdate,
      :commitdelta => time_delta_string(Time.now - commitdate),
      :committer   => committer,
    }
  end


  def assemble_template body_file
    body = body_file.read
    return body if body =~ /<html/

    head_file = @template_dir + '_head.rhtml'
    footer_file = @template_dir + '_footer.rhtml'

    <<-TEMPLATE
<!DOCTYPE html>

<html>
<head>


    TEMPLATE
  end


  def render file_name
    template_file = @template_dir + file_name

    template = template_for template_file, false, RDoc::ERBPartial

    template.filename = template_file.to_s

    template.result @context
  end


  def render_template template_file, out_file = nil # :yield: io
    io_output = out_file && !@dry_run && @file_output
    erb_klass = io_output ? RDoc::ERBIO : ERB

    template = template_for template_file, true, erb_klass

    if io_output then
      debug_msg "Outputting to %s" % [out_file.expand_path]

      out_file.dirname.mkpath
      out_file.open 'w', 0644 do |io|
        io.set_encoding @options.encoding if Object.const_defined? :Encoding

        @context = yield io

        template_result template, @context, template_file
      end
    else
      @context = yield nil

      output = template_result template, @context, template_file

      debug_msg "  would have written %d characters to %s" % [
        output.length, out_file.expand_path
      ] if @dry_run

      output
    end
  end


  def template_result template, context, template_file
    template.filename = template_file.to_s
    template.result context
  rescue NoMethodError => e
    raise RDoc::Error, "Error while evaluating %s: %s" % [
      template_file.expand_path,
      e.message,
    ], e.backtrace
  end


  def template_for file, page = true, klass = ERB
    template = @template_cache[file]

    return template if template

    if page then
      template = assemble_template file
      erbout = 'io'
    else
      template = file.read
      template = template.encode @options.encoding if
        Object.const_defined? :Encoding

      file_var = File.basename(file).sub(/\..*/, '')

      erbout = "_erbout_#{file_var}"
    end

    template = klass.new template, nil, '<>', erbout
    @template_cache[file] = template
    template
  end

end

