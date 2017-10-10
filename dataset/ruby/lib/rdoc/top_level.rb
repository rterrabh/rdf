
class RDoc::TopLevel < RDoc::Context

  MARSHAL_VERSION = 0 # :nodoc:


  attr_accessor :file_stat


  attr_accessor :relative_name


  attr_accessor :absolute_name


  attr_reader :classes_or_modules

  attr_accessor :diagram # :nodoc:


  attr_accessor :parser


  def initialize absolute_name, relative_name = absolute_name
    super()
    @name = nil
    @absolute_name = absolute_name
    @relative_name = relative_name
    @file_stat     = File.stat(absolute_name) rescue nil # HACK for testing
    @diagram       = nil
    @parser        = nil

    @classes_or_modules = []
  end


  def == other
    self.class === other and @relative_name == other.relative_name
  end

  alias eql? ==


  def add_alias(an_alias)
    object_class.record_location self
    return an_alias unless @document_self
    object_class.add_alias an_alias
  end


  def add_constant constant
    object_class.record_location self
    return constant unless @document_self
    object_class.add_constant constant
  end


  def add_include(include)
    object_class.record_location self
    return include unless @document_self
    object_class.add_include include
  end


  def add_method(method)
    object_class.record_location self
    return method unless @document_self
    object_class.add_method method
  end


  def add_to_classes_or_modules mod
    @classes_or_modules << mod
  end


  def base_name
    File.basename @relative_name
  end

  alias name base_name


  def display?
    text? and super
  end


  def find_class_or_module name
    @store.find_class_or_module name
  end


  def find_local_symbol(symbol)
    find_class_or_module(symbol) || super
  end


  def find_module_named(name)
    find_class_or_module(name)
  end


  def full_name
    @relative_name
  end


  def hash
    @relative_name.hash
  end


  def http_url(prefix)
    path = [prefix, @relative_name.tr('.', '_')]

    File.join(*path.compact) + '.html'
  end

  def inspect # :nodoc:
    "#<%s:0x%x %p modules: %p classes: %p>" % [
      self.class, object_id,
      base_name,
      @modules.map { |n,m| m },
      @classes.map { |n,c| c }
    ]
  end


  def last_modified
    @file_stat ? file_stat.mtime : nil
  end


  def marshal_dump
    [
      MARSHAL_VERSION,
      @relative_name,
      @parser,
      parse(@comment),
    ]
  end


  def marshal_load array # :nodoc:
    initialize array[1]

    @parser  = array[2]
    @comment = array[3]

    @file_stat          = nil
  end


  def object_class
    @object_class ||= begin
      oc = @store.find_class_named('Object') || add_class(RDoc::NormalClass, 'Object')
      oc.record_location self
      oc
    end
  end


  def page_name
    basename = File.basename @relative_name
    basename =~ /\.(rb|rdoc|txt|md)$/i

    $` || basename
  end


  def path
    http_url @store.rdoc.generator.file_dir
  end

  def pretty_print q # :nodoc:
    q.group 2, "[#{self.class}: ", "]" do
      q.text "base name: #{base_name.inspect}"
      q.breakable

      items = @modules.map { |n,m| m }
      items.concat @modules.map { |n,c| c }
      q.seplist items do |mod| q.pp mod end
    end
  end


  def search_record
    return unless @parser < RDoc::Parser::Text

    [
      page_name,
      '',
      page_name,
      '',
      path,
      '',
      snippet(@comment),
    ]
  end


  def text?
    @parser and @parser.ancestors.include? RDoc::Parser::Text
  end

  def to_s # :nodoc:
    "file #{full_name}"
  end

end

