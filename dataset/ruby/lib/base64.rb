

module Base64
  module_function

  def encode64(bin)
    [bin].pack("m")
  end

  def decode64(str)
    str.unpack("m").first
  end

  def strict_encode64(bin)
    [bin].pack("m0")
  end

  def strict_decode64(str)
    str.unpack("m0").first
  end

  def urlsafe_encode64(bin)
    strict_encode64(bin).tr("+/", "-_")
  end

  def urlsafe_decode64(str)
    strict_decode64(str.tr("-_", "+/"))
  end
end
