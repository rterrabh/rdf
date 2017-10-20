
class RDoc::MethodAttr < RDoc::CodeObject

  include Comparable


  attr_accessor :name


  attr_accessor :visibility


  attr_accessor :singleton


  attr_reader :text


  attr_reader :aliases


  attr_accessor :is_alias_for



  attr_reader :block_params


  attr_accessor :params


  attr_accessor :call_seq


  attr_reader :arglists


  attr_reader :param_seq



  def initialize text, name
    super()

    @text = text
    @name = name

    @aliases      = []
    @is_alias_for = nil
    @parent_name  = nil
    @singleton    = nil
    @visibility   = :public
    @see = false

    @arglists     = nil
    @block_params = nil
    @call_seq     = nil
    @param_seq    = nil
    @params       = nil
  end


  def initialize_copy other # :nodoc:
    @full_name = nil
  end

  def initialize_visibility # :nodoc:
    super
    @see = nil
  end


  def <=>(other)
    return unless other.respond_to?(:singleton) &&
                  other.respond_to?(:name)

    [     @singleton ? 0 : 1,       name] <=>
    [other.singleton ? 0 : 1, other.name]
  end

  def == other # :nodoc:
    equal?(other) or self.class == other.class and full_name == other.full_name
  end


  def documented?
    super or
      (is_alias_for and is_alias_for.documented?) or
      (see and see.documented?)
  end


  def see
    @see = find_see if @see == false
    @see
  end


  def store= store
    super

    @file = @store.add_file @file.full_name if @file
  end

  def find_see # :nodoc:
    return nil if singleton || is_alias_for

    other = find_method_or_attribute name
    return other if other

    return nil unless name =~ /[a-z_]=$/i   # avoid == or ===
    return find_method_or_attribute name[0..-2]
  end

  def find_method_or_attribute name # :nodoc:
    return nil unless parent.respond_to? :ancestors

    searched = parent.ancestors
    kernel = @store.modules_hash['Kernel']

    searched << kernel if kernel &&
      parent != kernel && !searched.include?(kernel)

    searched.each do |ancestor|
      next if String === ancestor
      next if parent == ancestor

      other = ancestor.find_method_named('#' << name) ||
              ancestor.find_attribute_named(name)

      return other if other
    end

    nil
  end


  def add_alias(an_alias, context)
    raise NotImplementedError
  end


  def aref
    type = singleton ? 'c' : 'i'
    "#{aref_prefix}-#{type}-#{html_name}"
  end


  def aref_prefix
    raise NotImplementedError
  end


  def block_params=(value)
    return @block_params = '' if value =~ /^[\.,]/

    return @block_params = '' if value =~ /^(if|unless)\s/

    value = $1.strip if value =~ /^(.+)\s(if|unless)\s/

    value = $1 if value =~ /^\s*\((.*)\)\s*$/
    value = value.strip

    return @block_params = $1 if value =~ /^(proc|lambda)(\s*\{|\sdo)/

    value = $1.strip if value =~ /^\+(.*)\+$/
    value = $1.strip if value =~ /^\[(.*)\]$/

    return @block_params = '' if value.empty?

    return @block_params = 'str' if value =~ /^\$[&0-9]$/

    value.gsub!(/(\w)\[[^\[]+\]/, '\1')

    value.gsub!(/@@?([a-z0-9_]+)/, '\1')

    value.gsub!(/([A-Z:a-z0-9_]+)\.([a-z0-9_]+)(\s*\(\s*[a-z0-9_.,\s]*\s*\)\s*)?/) do
      case $2
      when 'to_s'      then $1
      when 'const_get' then 'const'
      when 'new' then
        $1.split('::').last.  # ClassName => class_name
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          downcase
      else
        $2
      end
    end

    value.gsub!(/[A-Za-z0-9_:]+::/, '')

    value = $1 if value =~ /^([a-z0-9_]+)\s*[-*+\/]/

    @block_params = value.strip
  end


  def html_name
    require 'cgi'

    CGI.escape(@name.gsub('-', '-2D')).gsub('%','-').sub(/^-/, '')
  end


  def full_name
    @full_name ||= "#{parent_name}#{pretty_name}"
  end

  def inspect # :nodoc:
    alias_for = @is_alias_for ? " (alias for #{@is_alias_for.name})" : nil
    visibility = self.visibility
    visibility = "forced #{visibility}" if force_documentation
    "#<%s:0x%x %s (%s)%s>" % [
      self.class, object_id,
      full_name,
      visibility,
      alias_for,
    ]
  end


  def name_prefix
    @singleton ? '::' : '#'
  end


  def output_name context
    return "#{name_prefix}#{@name}" if context == parent

    "#{parent_name}#{@singleton ? '.' : '#'}#{@name}"
  end


  def pretty_name
    "#{name_prefix}#{@name}"
  end


  def type
    singleton ? 'class' : 'instance'
  end


  def path
    "#{@parent.path}##{aref}"
  end


  def parent_name
    @parent_name || super
  end

  def pretty_print q # :nodoc:
    alias_for =
      if @is_alias_for.respond_to? :name then
        "alias for #{@is_alias_for.name}"
      elsif Array === @is_alias_for then
        "alias for #{@is_alias_for.last}"
      end

    q.group 2, "[#{self.class.name} #{full_name} #{visibility}", "]" do
      if alias_for then
        q.breakable
        q.text alias_for
      end

      if text then
        q.breakable
        q.text "text:"
        q.breakable
        q.pp @text
      end

      unless comment.empty? then
        q.breakable
        q.text "comment:"
        q.breakable
        q.pp @comment
      end
    end
  end


  def search_record
    [
      @name,
      full_name,
      @name,
      @parent.full_name,
      path,
      params,
      snippet(@comment),
    ]
  end

  def to_s # :nodoc:
    if @is_alias_for
      "#{self.class.name}: #{full_name} -> #{is_alias_for}"
    else
      "#{self.class.name}: #{full_name}"
    end
  end

end

