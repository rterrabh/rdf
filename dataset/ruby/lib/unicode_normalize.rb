

class String
  def unicode_normalize(form = :nfc)
    require 'unicode_normalize/normalize.rb' unless defined? UnicodeNormalize
    UnicodeNormalize.normalize(self, form)
  end

  def unicode_normalize!(form = :nfc)
    require 'unicode_normalize/normalize.rb' unless defined? UnicodeNormalize
    replace(unicode_normalize(form))
  end

  def unicode_normalized?(form = :nfc)
    require 'unicode_normalize/normalize.rb' unless defined? UnicodeNormalize
    UnicodeNormalize.normalized?(self, form)
  end
end

