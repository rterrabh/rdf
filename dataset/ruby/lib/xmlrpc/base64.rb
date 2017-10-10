
module XMLRPC # :nodoc:

class Base64

  def initialize(str, state = :dec)
    case state
    when :enc
      @str = Base64.decode(str)
    when :dec
      @str = str
    else
      raise ArgumentError, "wrong argument; either :enc or :dec"
    end
  end

  def decoded
    @str
  end

  def encoded
    Base64.encode(@str)
  end


  def Base64.decode(str)
    str.gsub(/\s+/, "").unpack("m")[0]
  end

  def Base64.encode(str)
    [str].pack("m")
  end

end


end # module XMLRPC


=begin
= History
    $Id$
=end
