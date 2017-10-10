
module OpenSSL
  class BN
    include Comparable

    def pretty_print(q)
      q.object_group(self) {
        q.text ' '
        q.text to_i.to_s
      }
    end
  end # BN
end # OpenSSL

class Integer
  def to_bn
    OpenSSL::BN::new(self)
  end
end # Integer

