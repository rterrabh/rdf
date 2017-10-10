
module Salmon
  class EncryptedSlap < Slap
    include Diaspora::Logging

    def header(person)
      <<XML
        <encrypted_header>
        </encrypted_header>
XML
    end

    def plaintext_header
      header =<<HEADER
<decrypted_header>
    <iv>#{iv}</iv>
    <aes_key>#{aes_key}</aes_key>
    <author_id>#{@author.diaspora_handle}</author_id>
</decrypted_header>
HEADER
    end

    def xml_for(person)
      begin
        super
      rescue OpenSSL::PKey::RSAError => e
        logger.error "event=invalid_rsa_key identifier=#{person.diaspora_handle}"
        false
      end
    end

    def process_header(doc)
      self.author_id   = doc.search('author_id').text
      self.aes_key     = doc.search('aes_key').text
      self.iv          = doc.search('iv').text
    end

    def parse_data(user)
      user.aes_decrypt(super, {'key' => self.aes_key, 'iv' => self.iv})
    end

    def salmon_header(doc, user)
      header = user.decrypt(doc.search('encrypted_header').text)
      Nokogiri::XML(header)
    end

    def self.payload(activity, user, aes_key_hash)
      user.person.aes_encrypt(activity, aes_key_hash)
    end
  end
end
