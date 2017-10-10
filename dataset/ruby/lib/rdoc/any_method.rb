
class RDoc::AnyMethod < RDoc::MethodAttr


  MARSHAL_VERSION = 3 # :nodoc:


  attr_accessor :dont_rename_initialize


  attr_accessor :c_function


  attr_reader :call_seq


  attr_accessor :params


  attr_accessor :calls_super

  include RDoc::TokenStream


  def initialize text, name
    super

    @c_function = nil
    @dont_rename_initialize = false
    @token_stream = nil
    @calls_super = false
    @superclass_method = nil
  end


  def add_alias an_alias, context = nil
    method = self.class.new an_alias.text, an_alias.new_name

    method.record_location an_alias.file
    method.singleton = self.singleton
    method.params = self.params
    method.visibility = self.visibility
    method.comment = an_alias.comment
    method.is_alias_for = self
    @aliases << method
    context.add_method method if context
    method
  end


  def aref_prefix
    'method'
  end


  def arglists
    if @call_seq then
      @call_seq
    elsif @params then
      "#{name}#{param_seq}"
    end
  end


  def call_seq= call_seq
    return if call_seq.empty?

    @call_seq = call_seq
  end


  def is_alias_for # :nodoc:
    case @is_alias_for
    when RDoc::MethodAttr then
      @is_alias_for
    when Array then
      return nil unless @store

      klass_name, singleton, method_name = @is_alias_for

      return nil unless klass = @store.find_class_or_module(klass_name)

      @is_alias_for = klass.find_method method_name, singleton
    end
  end


  def marshal_dump
    aliases = @aliases.map do |a|
      [a.name, parse(a.comment)]
    end

    is_alias_for = [
      @is_alias_for.parent.full_name,
      @is_alias_for.singleton,
      @is_alias_for.name
    ] if @is_alias_for

    [ MARSHAL_VERSION,
      @name,
      full_name,
      @singleton,
      @visibility,
      parse(@comment),
      @call_seq,
      @block_params,
      aliases,
      @params,
      @file.relative_name,
      @calls_super,
      @parent.name,
      @parent.class,
      @section.title,
      is_alias_for,
    ]
  end


  def marshal_load array
    initialize_visibility

    @dont_rename_initialize = nil
    @token_stream           = nil
    @aliases                = []
    @parent                 = nil
    @parent_name            = nil
    @parent_class           = nil
    @section                = nil
    @file                   = nil

    version        = array[0]
    @name          = array[1]
    @full_name     = array[2]
    @singleton     = array[3]
    @visibility    = array[4]
    @comment       = array[5]
    @call_seq      = array[6]
    @block_params  = array[7]
    @params        = array[9]
    @calls_super   = array[11]
    @parent_name   = array[12]
    @parent_title  = array[13]
    @section_title = array[14]
    @is_alias_for  = array[15]

    array[8].each do |new_name, comment|
      add_alias RDoc::Alias.new(nil, @name, new_name, comment, @singleton)
    end

    @parent_name ||= if @full_name =~ /#/ then
                       $`
                     else
                       name = @full_name.split('::')
                       name.pop
                       name.join '::'
                     end

    @file = RDoc::TopLevel.new array[10] if version > 0
  end


  def name
    return @name if @name

    @name =
      @call_seq[/^.*?\.(\w+)/, 1] ||
      @call_seq[/^.*?(\w+)/, 1] ||
      @call_seq if @call_seq
  end


  def param_list
    if @call_seq then
      params = @call_seq.split("\n").last
      params = params.sub(/.*?\((.*)\)/, '\1')
      params = params.sub(/(\{|do)\s*\|([^|]*)\|.*/, ',\2')
    elsif @params then
      params = @params.sub(/\((.*)\)/, '\1')

      params << ",#{@block_params}" if @block_params
    elsif @block_params then
      params = @block_params
    else
      return []
    end

    if @block_params then
      params.sub!(/,?\s*&\w+/, '')
    else
      params.sub!(/\&(\w+)/, '\1')
    end

    params = params.gsub(/\s+/, '').split(',').reject(&:empty?)

    params.map { |param| param.sub(/=.*/, '') }
  end


  def param_seq
    if @call_seq then
      params = @call_seq.split("\n").last
      params = params.sub(/[^( ]+/, '')
      params = params.sub(/(\|[^|]+\|)\s*\.\.\.\s*(end|\})/, '\1 \2')
    elsif @params then
      params = @params.gsub(/\s*\#.*/, '')
      params = params.tr("\n", " ").squeeze(" ")
      params = "(#{params})" unless params[0] == ?(
    else
      params = ''
    end

    if @block_params then
      params.sub!(/,?\s*&\w+/, '')

      block = @block_params.gsub(/\s*\#.*/, '')
      block = block.tr("\n", " ").squeeze(" ")
      if block[0] == ?(
        block.sub!(/^\(/, '').sub!(/\)/, '')
      end
      params << " { |#{block}| ... }"
    end

    params
  end


  def store= store
    super

    @file = @store.add_file @file.full_name if @file
  end


  def superclass_method
    return unless @calls_super
    return @superclass_method if @superclass_method

    parent.each_ancestor do |ancestor|
      if method = ancestor.method_list.find { |m| m.name == @name } then
        @superclass_method = method
        break
      end
    end

    @superclass_method
  end

end

