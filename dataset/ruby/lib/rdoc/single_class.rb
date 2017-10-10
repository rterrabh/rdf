
class RDoc::SingleClass < RDoc::ClassModule


  def ancestors
    superclass ? super + [superclass] : super
  end

  def aref_prefix # :nodoc:
    'sclass'
  end


  def definition
    "class << #{full_name}"
  end

end

