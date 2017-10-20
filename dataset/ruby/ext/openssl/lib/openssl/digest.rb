
module OpenSSL
  class Digest

    alg = %w(DSS DSS1 MD2 MD4 MD5 MDC2 RIPEMD160 SHA SHA1)
    if OPENSSL_VERSION_NUMBER > 0x00908000
      alg += %w(SHA224 SHA256 SHA384 SHA512)
    end


    def self.digest(name, data)
      super(data, name)
    end

    alg.each{|name|
      klass = Class.new(self) {
        #nodyna <define_method-1498> <DM MODERATE (events)>
        define_method(:initialize, ->(data = nil) {super(name, data)})
      }
      singleton = (class << klass; self; end)
      #nodyna <class_eval-1499> <CE MODERATE (define methods)>
      singleton.class_eval{
        #nodyna <define_method-1500> <DM MODERATE (events)>
        define_method(:digest){|data| new.digest(data) }
        #nodyna <define_method-1501> <DM MODERATE (events)>
        define_method(:hexdigest){|data| new.hexdigest(data) }
      }
      #nodyna <const_set-1502> <CS MODERATE (change-prone variable)>
      const_set(name, klass)
    }

    class Digest < Digest # :nodoc:
      def initialize(*args)
        warn('Digest::Digest is deprecated; use Digest')
        super(*args)
      end
    end

  end # Digest


  def Digest(name)
    #nodyna <const_get-1503> <CG COMPLEX (change-prone variable)>
    OpenSSL::Digest.const_get(name)
  end

  module_function :Digest

end # OpenSSL

