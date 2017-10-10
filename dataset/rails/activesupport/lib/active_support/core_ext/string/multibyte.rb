require 'active_support/multibyte'

class String
  def mb_chars
    ActiveSupport::Multibyte.proxy_class.new(self)
  end

  def is_utf8?
    case encoding
    when Encoding::UTF_8
      valid_encoding?
    when Encoding::ASCII_8BIT, Encoding::US_ASCII
      dup.force_encoding(Encoding::UTF_8).valid_encoding?
    else
      false
    end
  end
end
