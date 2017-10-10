require 'securerandom'

module Digest
  module UUID
    DNS_NAMESPACE  = "k\xA7\xB8\x10\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    URL_NAMESPACE  = "k\xA7\xB8\x11\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    OID_NAMESPACE  = "k\xA7\xB8\x12\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:
    X500_NAMESPACE = "k\xA7\xB8\x14\x9D\xAD\x11\xD1\x80\xB4\x00\xC0O\xD40\xC8" #:nodoc:

    def self.uuid_from_hash(hash_class, uuid_namespace, name)
      if hash_class == Digest::MD5
        version = 3
      elsif hash_class == Digest::SHA1
        version = 5
      else
        raise ArgumentError, "Expected Digest::SHA1 or Digest::MD5, got #{hash_class.name}."
      end

      hash = hash_class.new
      hash.update(uuid_namespace)
      hash.update(name)

      ary = hash.digest.unpack('NnnnnN')
      ary[2] = (ary[2] & 0x0FFF) | (version << 12)
      ary[3] = (ary[3] & 0x3FFF) | 0x8000

      "%08x-%04x-%04x-%04x-%04x%08x" % ary
    end

    def self.uuid_v3(uuid_namespace, name)
      self.uuid_from_hash(Digest::MD5, uuid_namespace, name)
    end

    def self.uuid_v5(uuid_namespace, name)
      self.uuid_from_hash(Digest::SHA1, uuid_namespace, name)
    end

    def self.uuid_v4
      SecureRandom.uuid
    end
  end
end
