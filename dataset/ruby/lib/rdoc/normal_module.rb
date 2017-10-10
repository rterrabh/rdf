
class RDoc::NormalModule < RDoc::ClassModule

  def aref_prefix # :nodoc:
    'module'
  end

  def inspect # :nodoc:
    "#<%s:0x%x module %s includes: %p extends: %p attributes: %p methods: %p aliases: %p>" % [
      self.class, object_id,
      full_name, @includes, @extends, @attributes, @method_list, @aliases
    ]
  end


  def definition
    "module #{full_name}"
  end


  def module?
    true
  end

  def pretty_print q # :nodoc:
    q.group 2, "[module #{full_name}: ", "]" do
      q.breakable
      q.text "includes:"
      q.breakable
      q.seplist @includes do |inc| q.pp inc end
      q.breakable

      q.breakable
      q.text "constants:"
      q.breakable
      q.seplist @constants do |const| q.pp const end

      q.text "attributes:"
      q.breakable
      q.seplist @attributes do |attr| q.pp attr end
      q.breakable

      q.text "methods:"
      q.breakable
      q.seplist @method_list do |meth| q.pp meth end
      q.breakable

      q.text "aliases:"
      q.breakable
      q.seplist @aliases do |aliaz| q.pp aliaz end
      q.breakable

      q.text "comment:"
      q.breakable
      q.pp comment
    end
  end


  def superclass
    raise NoMethodError, "#{full_name} is a module"
  end

end

