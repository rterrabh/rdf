
require 'nkf'

module Kconv


  AUTO = NKF::AUTO
  JIS = NKF::JIS
  EUC = NKF::EUC
  SJIS = NKF::SJIS
  BINARY = NKF::BINARY
  NOCONV = NKF::NOCONV
  ASCII = NKF::ASCII
  UTF8 = NKF::UTF8
  UTF16 = NKF::UTF16
  UTF32 = NKF::UTF32
  UNKNOWN = NKF::UNKNOWN


  def kconv(str, to_enc, from_enc=nil)
    opt = ''
    opt += ' --ic=' + from_enc.to_s if from_enc
    opt += ' --oc=' + to_enc.to_s if to_enc

    ::NKF::nkf(opt, str)
  end
  module_function :kconv


  def tojis(str)
    kconv(str, JIS)
  end
  module_function :tojis

  def toeuc(str)
    kconv(str, EUC)
  end
  module_function :toeuc

  def tosjis(str)
    kconv(str, SJIS)
  end
  module_function :tosjis

  def toutf8(str)
    kconv(str, UTF8)
  end
  module_function :toutf8

  def toutf16(str)
    kconv(str, UTF16)
  end
  module_function :toutf16

  def toutf32(str)
    kconv(str, UTF32)
  end
  module_function :toutf32

  def tolocale(str)
    kconv(str, Encoding.locale_charmap)
  end
  module_function :tolocale


  def guess(str)
    ::NKF::guess(str)
  end
  module_function :guess


  def iseuc(str)
    str.dup.force_encoding(EUC).valid_encoding?
  end
  module_function :iseuc

  def issjis(str)
    str.dup.force_encoding(SJIS).valid_encoding?
  end
  module_function :issjis

  def isjis(str)
    /\A [\t\n\r\x20-\x7E]*
      (?:
        (?:\x1b \x28 I      [\x21-\x7E]*
          |\x1b \x28 J      [\x21-\x7E]*
          |\x1b \x24 @      (?:[\x21-\x7E]{2})*
          |\x1b \x24 B      (?:[\x21-\x7E]{2})*
          |\x1b \x24 \x28 D (?:[\x21-\x7E]{2})*
        )*
        \x1b \x28 B [\t\n\r\x20-\x7E]*
      )*
     \z/nox =~ str.dup.force_encoding('BINARY') ? true : false
  end
  module_function :isjis

  def isutf8(str)
    str.dup.force_encoding(UTF8).valid_encoding?
  end
  module_function :isutf8
end

class String
  def kconv(to_enc, from_enc=nil)
    from_enc = self.encoding if !from_enc && self.encoding != Encoding.list[0]
    Kconv::kconv(self, to_enc, from_enc)
  end


  def tojis; Kconv.tojis(self) end

  def toeuc; Kconv.toeuc(self) end

  def tosjis; Kconv.tosjis(self) end

  def toutf8; Kconv.toutf8(self) end

  def toutf16; Kconv.toutf16(self) end

  def toutf32; Kconv.toutf32(self) end

  def tolocale; Kconv.tolocale(self) end


  def iseuc;	Kconv.iseuc(self) end

  def issjis;	Kconv.issjis(self) end

  def isjis;	Kconv.isjis(self) end

  def isutf8;	Kconv.isutf8(self) end
end
