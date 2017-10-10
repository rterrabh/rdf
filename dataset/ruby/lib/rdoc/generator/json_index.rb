require 'json'
require 'zlib'


class RDoc::Generator::JsonIndex

  include RDoc::Text


  SEARCH_INDEX_FILE = File.join 'js', 'search_index.js'

  attr_reader :index # :nodoc:


  def initialize parent_generator, options
    @parent_generator = parent_generator
    @store            = parent_generator.store
    @options          = options

    @template_dir = File.expand_path '../template/json_index', __FILE__
    @base_dir = @parent_generator.base_dir

    @classes = nil
    @files   = nil
    @index   = nil
  end


  def build_index
    reset @store.all_files.sort, @store.all_classes_and_modules.sort

    index_classes
    index_methods
    index_pages

    { :index => @index }
  end


  def debug_msg *msg
    return unless $DEBUG_RDOC
    $stderr.puts(*msg)
  end


  def generate
    debug_msg "Generating JSON index"

    debug_msg "  writing search index to %s" % SEARCH_INDEX_FILE
    data = build_index

    return if @options.dry_run

    out_dir = @base_dir + @options.op_dir
    index_file = out_dir + SEARCH_INDEX_FILE

    FileUtils.mkdir_p index_file.dirname, :verbose => $DEBUG_RDOC

    index_file.open 'w', 0644 do |io|
      io.set_encoding Encoding::UTF_8 if Object.const_defined? :Encoding
      io.write 'var search_data = '

      JSON.dump data, io, 0
    end

    Dir.chdir @template_dir do
      Dir['**/*.js'].each do |source|
        dest = File.join out_dir, source

        FileUtils.install source, dest, :mode => 0644, :verbose => $DEBUG_RDOC
      end
    end
  end


  def generate_gzipped
    debug_msg "Compressing generated JSON index"
    out_dir = @base_dir + @options.op_dir

    search_index_file = out_dir + SEARCH_INDEX_FILE
    outfile           = out_dir + "#{search_index_file}.gz"

    debug_msg "Reading the JSON index file from %s" % search_index_file
    search_index = search_index_file.read

    debug_msg "Writing gzipped search index to %s" % outfile

    Zlib::GzipWriter.open(outfile) do |gz|
      gz.mtime = File.mtime(search_index_file)
      gz.orig_name = search_index_file.to_s
      gz.write search_index
      gz.close
    end

    Dir.chdir @template_dir do
      Dir['**/*.js'].each do |source|
        dest = out_dir + source
        outfile = out_dir + "#{dest}.gz"

        debug_msg "Reading the original js file from %s" % dest
        data = dest.read

        debug_msg "Writing gzipped file to %s" % outfile

        Zlib::GzipWriter.open(outfile) do |gz|
          gz.mtime = File.mtime(dest)
          gz.orig_name = dest.to_s
          gz.write data
          gz.close
        end
      end
    end
  end


  def index_classes
    debug_msg "  generating class search index"

    documented = @classes.uniq.select do |klass|
      klass.document_self_or_methods
    end

    documented.each do |klass|
      debug_msg "    #{klass.full_name}"
      record = klass.search_record
      @index[:searchIndex]     << search_string(record.shift)
      @index[:longSearchIndex] << search_string(record.shift)
      @index[:info]            << record
    end
  end


  def index_methods
    debug_msg "  generating method search index"

    list = @classes.uniq.map do |klass|
      klass.method_list
    end.flatten.sort_by do |method|
      [method.name, method.parent.full_name]
    end

    list.each do |method|
      debug_msg "    #{method.full_name}"
      record = method.search_record
      @index[:searchIndex]     << "#{search_string record.shift}()"
      @index[:longSearchIndex] << "#{search_string record.shift}()"
      @index[:info]            << record
    end
  end


  def index_pages
    debug_msg "  generating pages search index"

    pages = @files.select do |file|
      file.text?
    end

    pages.each do |page|
      debug_msg "    #{page.page_name}"
      record = page.search_record
      @index[:searchIndex]     << search_string(record.shift)
      @index[:longSearchIndex] << ''
      record.shift
      @index[:info]            << record
    end
  end


  def class_dir
    @parent_generator.class_dir
  end


  def file_dir
    @parent_generator.file_dir
  end

  def reset files, classes # :nodoc:
    @files   = files
    @classes = classes

    @index = {
      :searchIndex => [],
      :longSearchIndex => [],
      :info => []
    }
  end


  def search_string string
    string.downcase.gsub(/\s/, '')
  end

end

