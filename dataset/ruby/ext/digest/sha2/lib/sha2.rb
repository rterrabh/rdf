
require 'digest'
require 'digest/sha2.so'

module Digest
  class SHA2 < Digest::Class
    def initialize(bitlen = 256)
      case bitlen
      when 256
        @sha2 = Digest::SHA256.new
      when 384
        @sha2 = Digest::SHA384.new
      when 512
        @sha2 = Digest::SHA512.new
      else
        raise ArgumentError, "unsupported bit length: %s" % bitlen.inspect
      end
      @bitlen = bitlen
    end

    def reset
      @sha2.reset
      self
    end

    def update(str)
      @sha2.update(str)
      self
    end
    alias << update

    def finish # :nodoc:
      @sha2.digest!
    end
    private :finish


    def block_length
      @sha2.block_length
    end

    def digest_length
      @sha2.digest_length
    end

    def initialize_copy(other) # :nodoc:
      #nodyna <instance_eval-1519> <IEV COMPLEX (private access)>
      @sha2 = other.instance_eval { @sha2.clone }
    end

    def inspect # :nodoc:
      "#<%s:%d %s>" % [self.class.name, @bitlen, hexdigest]
    end
  end
end
