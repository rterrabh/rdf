
class RDoc::CodeObject

  include RDoc::Text


  attr_reader :comment


  attr_reader :document_children


  attr_reader :document_self


  attr_reader :done_documenting


  attr_reader :file


  attr_reader :force_documentation


  attr_accessor :line


  attr_reader :metadata


  attr_accessor :offset


  attr_writer :parent


  attr_reader :received_nodoc


  attr_writer :section


  attr_reader :store


  attr_accessor :viewer


  def initialize
    @metadata         = {}
    @comment          = ''
    @parent           = nil
    @parent_name      = nil # for loading
    @parent_class     = nil # for loading
    @section          = nil
    @section_title    = nil # for loading
    @file             = nil
    @full_name        = nil
    @store            = nil
    @track_visibility = true

    initialize_visibility
  end


  def initialize_visibility # :nodoc:
    @document_children   = true
    @document_self       = true
    @done_documenting    = false
    @force_documentation = false
    @received_nodoc      = false
    @ignored             = false
    @suppressed          = false
    @track_visibility    = true
  end


  def comment=(comment)
    @comment = case comment
               when NilClass               then ''
               when RDoc::Markup::Document then comment
               when RDoc::Comment          then comment.normalize
               else
                 if comment and not comment.empty? then
                   normalize_comment comment
                 else
                   if String === @comment and
                      Object.const_defined? :Encoding and @comment.empty? then
                     @comment.force_encoding comment.encoding
                   end
                   @comment
                 end
               end
  end


  def display?
    @document_self and not @ignored and
      (documented? or not @suppressed)
  end


  def document_children=(document_children)
    return unless @track_visibility

    @document_children = document_children unless @done_documenting
  end


  def document_self=(document_self)
    return unless @track_visibility
    return if @done_documenting

    @document_self = document_self
    @received_nodoc = true if document_self.nil?
  end


  def documented?
    @received_nodoc or !@comment.empty?
  end


  def done_documenting=(value)
    return unless @track_visibility
    @done_documenting  = value
    @document_self     = !value
    @document_children = @document_self
  end


  def each_parent
    code_object = self

    while code_object = code_object.parent do
      yield code_object
    end

    self
  end


  def file_name
    return unless @file

    @file.absolute_name
  end


  def force_documentation=(value)
    @force_documentation = value unless @done_documenting
  end


  def full_name= full_name
    @full_name = full_name
  end


  def ignore
    return unless @track_visibility

    @ignored = true

    stop_doc
  end


  def ignored?
    @ignored
  end


  def options
    if @store and @store.rdoc then
      @store.rdoc.options
    else
      RDoc::Options.new
    end
  end


  def parent
    return @parent if @parent
    return nil unless @parent_name

    if @parent_class == RDoc::TopLevel then
      @parent = @store.add_file @parent_name
    else
      @parent = @store.find_class_or_module @parent_name

      return @parent if @parent

      begin
        @parent = @store.load_class @parent_name
      rescue RDoc::Store::MissingFileError
        nil
      end
    end
  end


  def parent_file_name
    @parent ? @parent.base_name : '(unknown)'
  end


  def parent_name
    @parent ? @parent.full_name : '(unknown)'
  end


  def record_location top_level
    @ignored    = false
    @suppressed = false
    @file       = top_level
  end


  def section
    return @section if @section

    @section = parent.add_section @section_title if parent
  end


  def start_doc
    return if @done_documenting

    @document_self = true
    @document_children = true
    @ignored    = false
    @suppressed = false
  end


  def stop_doc
    return unless @track_visibility

    @document_self = false
    @document_children = false
  end


  def store= store
    @store = store

    return unless @track_visibility

    if :nodoc == options.visibility then
      initialize_visibility
      @track_visibility = false
    end
  end


  def suppress
    return unless @track_visibility

    @suppressed = true

    stop_doc
  end


  def suppressed?
    @suppressed
  end

end

