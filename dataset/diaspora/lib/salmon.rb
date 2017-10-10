
module Base64
  module_function
  def urlsafe_encode64(bin)
    self.strict_encode64(bin).tr("+/", "-_")
  end

  def urlsafe_decode64(str)
    self.decode64(str.tr("-_", "+/"))
  end
end

module Salmon
  require "salmon/slap"
  require "salmon/encrypted_slap"
  require "salmon/magic_sig_envelope"
end
