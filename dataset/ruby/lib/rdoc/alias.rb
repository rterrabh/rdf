
class RDoc::Alias < RDoc::CodeObject


  attr_reader :new_name

  alias name new_name


  attr_reader :old_name


  attr_accessor :singleton


  attr_reader :text


  def initialize(text, old_name, new_name, comment, singleton = false)
    super()

    @text = text
    @singleton = singleton
    @old_name = old_name
    @new_name = new_name
    self.comment = comment
  end


  def <=>(other)
    [@singleton ? 0 : 1, new_name] <=> [other.singleton ? 0 : 1, other.new_name]
  end


  def aref
    type = singleton ? 'c' : 'i'
    "#alias-#{type}-#{html_name}"
  end


  def full_old_name
    @full_name || "#{parent.name}#{pretty_old_name}"
  end


  def html_name
    CGI.escape(@new_name.gsub('-', '-2D')).gsub('%','-').sub(/^-/, '')
  end

  def inspect # :nodoc:
    parent_name = parent ? parent.name : '(unknown)'
    "#<%s:0x%x %s.alias_method %s, %s>" % [
      self.class, object_id,
      parent_name, @old_name, @new_name,
    ]
  end


  def name_prefix
    singleton ? '::' : '#'
  end


  def pretty_old_name
    "#{singleton ? '::' : '#'}#{@old_name}"
  end


  def pretty_new_name
    "#{singleton ? '::' : '#'}#{@new_name}"
  end

  alias pretty_name pretty_new_name

  def to_s # :nodoc:
    "alias: #{self.new_name} -> #{self.pretty_old_name} in: #{parent}"
  end

end

