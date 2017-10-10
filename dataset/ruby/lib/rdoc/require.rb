
class RDoc::Require < RDoc::CodeObject


  attr_accessor :name


  def initialize(name, comment)
    super()
    @name = name.gsub(/'|"/, "") #'
    @top_level = nil
    self.comment = comment
  end

  def inspect # :nodoc:
    "#<%s:0x%x require '%s' in %s>" % [
      self.class,
      object_id,
      @name,
      parent_file_name,
    ]
  end

  def to_s # :nodoc:
    "require #{name} in: #{parent}"
  end


  def top_level
    @top_level ||= begin
      tl = RDoc::TopLevel.all_files_hash[name + '.rb']

      if tl.nil? and RDoc::TopLevel.all_files.first.full_name =~ %r(^lib/) then
        tl = RDoc::TopLevel.all_files_hash['lib/' + name + '.rb']
      end

      tl
    end
  end

end

