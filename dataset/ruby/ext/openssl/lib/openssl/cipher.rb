
module OpenSSL
  class Cipher
    %w(AES CAST5 BF DES IDEA RC2 RC4 RC5).each{|name|
      klass = Class.new(Cipher){
        #nodyna <define_method-1504> <DM MODERATE (array)>
        define_method(:initialize){|*args|
          cipher_name = args.inject(name){|n, arg| "#{n}-#{arg}" }
          super(cipher_name)
        }
      }
      #nodyna <const_set-1505> <CS MEDIUM (array)>
      const_set(name, klass)
    }

    %w(128 192 256).each{|keylen|
      klass = Class.new(Cipher){
        #nodyna <define_method-1506> <DM MODERATE (array)>
        define_method(:initialize){|mode|
          mode ||= "CBC"
          cipher_name = "AES-#{keylen}-#{mode}"
          super(cipher_name)
        }
      }
      #nodyna <const_set-1507> <CS MEDIUM (array)>
      const_set("AES#{keylen}", klass)
    }

    def random_key
      str = OpenSSL::Random.random_bytes(self.key_len)
      self.key = str
      return str
    end

    def random_iv
      str = OpenSSL::Random.random_bytes(self.iv_len)
      self.iv = str
      return str
    end

    class Cipher < Cipher
    end
  end # Cipher
end # OpenSSL
