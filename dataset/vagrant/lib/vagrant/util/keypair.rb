require "base64"
require "openssl"

require "vagrant/util/retryable"

module Vagrant
  module Util
    class Keypair
      extend Retryable

      def self.create(password=nil)
        rsa_key = nil
        retryable(on: OpenSSL::PKey::RSAError, sleep: 2, tries: 5) do
          rsa_key = OpenSSL::PKey::RSA.new(2048)
        end

        public_key  = rsa_key.public_key
        private_key = rsa_key.to_pem

        if password
          cipher      = OpenSSL::Cipher::Cipher.new('des3')
          private_key = rsa_key.to_pem(cipher, password)
        end

        binary = [7].pack("N")
        binary += "ssh-rsa"
        ["e", "n"].each do |m|
          #nodyna <send-3083> <SD MODERATE (array)>
          val  = public_key.send(m)
          data = val.to_s(2)

          first_byte = data[0,1].unpack("c").first
          if val < 0
            data[0] = [0x80 & first_byte].pack("c")
          elsif first_byte < 0
            data = 0.chr + data
          end

          binary += [data.length].pack("N") + data
        end

        openssh_key = "ssh-rsa #{Base64.encode64(binary).gsub("\n", "")} vagrant"
        public_key  = public_key.to_pem
        return [public_key, private_key, openssh_key]
      end
    end
  end
end
