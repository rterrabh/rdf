
class RDoc::Mixin < RDoc::CodeObject


  attr_accessor :name


  def initialize(name, comment)
    super()
    @name = name
    self.comment = comment
    @module = nil # cache for module if found
  end


  def <=> other
    return unless self.class === other

    name <=> other.name
  end

  def == other # :nodoc:
    self.class === other and @name == other.name
  end

  alias eql? == # :nodoc:


  def full_name
    m = self.module
    RDoc::ClassModule === m ? m.full_name : @name
  end

  def hash # :nodoc:
    [@name, self.module].hash
  end

  def inspect # :nodoc:
    "#<%s:0x%x %s.%s %s>" % [
      self.class,
      object_id,
      parent_name, self.class.name.downcase, @name,
    ]
  end


  def module
    return @module if @module

    return @name unless parent
    full_name = parent.child_name(@name)
    @module = @store.modules_hash[full_name]
    return @module if @module
    return @name if @name =~ /^::/

    searched = parent.includes.take_while { |i| i != self }.reverse
    searched.each do |i|
      inc = i.module
      next if String === inc
      full_name = inc.child_name(@name)
      @module = @store.modules_hash[full_name]
      return @module if @module
    end

    up = parent.parent
    while up
      full_name = up.child_name(@name)
      @module = @store.modules_hash[full_name]
      return @module if @module
      up = up.parent
    end

    @name
  end


  def store= store
    super

    @file = @store.add_file @file.full_name if @file
  end

  def to_s # :nodoc:
    "#{self.class.name.downcase} #@name in: #{parent}"
  end

end

