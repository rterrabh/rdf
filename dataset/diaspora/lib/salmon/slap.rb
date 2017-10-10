
module Salmon
 class Slap
    attr_accessor :magic_sig, :author, :author_id, :parsed_data
    attr_accessor :aes_key, :iv

    delegate :sig, :data_type, :to => :magic_sig

    def self.create_by_user_and_activity(user, activity)
      salmon = self.new
      salmon.author   = user.person
      aes_key_hash    = user.person.gen_aes_key

      salmon.aes_key  = aes_key_hash['key']
      salmon.iv       = aes_key_hash['iv']

      salmon.magic_sig = MagicSigEnvelope.create(user, self.payload(activity, user, aes_key_hash))
      salmon
    end

    def self.from_xml(xml, receiving_user=nil)
      slap = self.new
      doc = Nokogiri::XML(xml)

      root_doc = doc.search('diaspora')

      header_doc       = slap.salmon_header(doc, receiving_user) 
      slap.process_header(header_doc)

      slap.magic_sig = MagicSigEnvelope.parse(root_doc)

      slap.parsed_data = slap.parse_data(receiving_user)

      slap
    end

    def self.payload(activity, user=nil, aes_key_hash=nil)
      activity
    end

    def process_header(doc)
      self.author_id   = doc.search('author_id').text
    end

    def parse_data(user=nil)
      Slap.decode64url(self.magic_sig.data)
    end

    def salmon_header(doc, user=nil)
      doc.search('header')
    end

    def xml_for(person)
      @xml =<<ENTRY
    <?xml version='1.0' encoding='UTF-8'?>
    <diaspora xmlns="https://joindiaspora.com/protocol" xmlns:me="http://salmon-protocol.org/ns/magic-env">
    </diaspora>
ENTRY
    end

    def header(person)
      "<header>#{plaintext_header}</header>"
    end

    def plaintext_header
      header =<<HEADER
    <author_id>#{@author.diaspora_handle}</author_id>
HEADER
    end

    def author
      if @author.nil?
        @author ||= Person.by_account_identifier @author_id
        raise "did you remember to async webfinger?" if @author.nil?
      end
      @author
    end

    def self.decode64url(str)
      sans_whitespace = str.gsub(/\s/, '')
      string = sans_whitespace + '=' * ((4 - sans_whitespace.size) % 4)

      Base64.urlsafe_decode64 string
    end

    def verified_for_key?(public_key)
      signature = Base64.urlsafe_decode64(self.magic_sig.sig)
      signed_data = self.magic_sig.signable_string# Base64.urlsafe_decode64(self.magic_sig.signable_string)

      public_key.verify(OpenSSL::Digest::SHA256.new, signature, signed_data )
    end

    def self.b64_to_n(str)
      packed = decode64url(str)
      packed.unpack('B*')[0].to_i(2)
    end

    def self.parse_key(str)
      n,e = str.match(/^RSA.([^.]*).([^.]*)$/)[1..2]
      build_key(b64_to_n(n),b64_to_n(e))
    end

    def self.build_key(n,e)
      key = OpenSSL::PKey::RSA.new
      key.n = n
      key.e = e
      key
    end
  end
end
