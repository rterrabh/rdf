
class RDoc::Constant < RDoc::CodeObject

  MARSHAL_VERSION = 0 # :nodoc:


  attr_writer :is_alias_for


  attr_accessor :name


  attr_accessor :value


  attr_accessor :visibility


  def initialize(name, value, comment)
    super()

    @name  = name
    @value = value

    @is_alias_for = nil
    @visibility   = nil

    self.comment = comment
  end


  def <=> other
    return unless self.class === other

    [parent_name, name] <=> [other.parent_name, other.name]
  end


  def == other
    self.class == other.class and
      @parent == other.parent and
      @name == other.name
  end


  def documented?
    return true if super
    return false unless @is_alias_for
    case @is_alias_for
    when String then
      found = @store.find_class_or_module @is_alias_for
      return false unless found
      @is_alias_for = found
    end
    @is_alias_for.documented?
  end


  def full_name
    @full_name ||= "#{parent_name}::#{@name}"
  end


  def is_alias_for
    case @is_alias_for
    when String then
      found = @store.find_class_or_module @is_alias_for
      @is_alias_for = found if found
      @is_alias_for
    else
      @is_alias_for
    end
  end

  def inspect # :nodoc:
    "#<%s:0x%x %s::%s>" % [
      self.class, object_id,
      parent_name, @name,
    ]
  end


  def marshal_dump
    alias_name = case found = is_alias_for
                 when RDoc::CodeObject then found.full_name
                 else                       found
                 end

    [ MARSHAL_VERSION,
      @name,
      full_name,
      @visibility,
      alias_name,
      parse(@comment),
      @file.relative_name,
      parent.name,
      parent.class,
      section.title,
    ]
  end


  def marshal_load array
    initialize array[1], nil, array[5]

    @full_name     = array[2]
    @visibility    = array[3]
    @is_alias_for  = array[4]
    @parent_name   = array[7]
    @parent_class  = array[8]
    @section_title = array[9]

    @file = RDoc::TopLevel.new array[6]
  end


  def path
    "#{@parent.path}##{@name}"
  end

  def pretty_print q # :nodoc:
    q.group 2, "[#{self.class.name} #{full_name}", "]" do
      unless comment.empty? then
        q.breakable
        q.text "comment:"
        q.breakable
        q.pp @comment
      end
    end
  end


  def store= store
    super

    @file = @store.add_file @file.full_name if @file
  end

  def to_s # :nodoc:
    parent_name = parent ? parent.full_name : '(unknown)'
    if is_alias_for
      "constant #{parent_name}::#@name -> #{is_alias_for}"
    else
      "constant #{parent_name}::#@name"
    end
  end

end

