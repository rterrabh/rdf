
require 'rubygems/exceptions'
require 'fileutils'

begin
  require 'openssl'
rescue LoadError => e
  raise unless (e.respond_to?(:path) && e.path == 'openssl') ||
               e.message =~ / -- openssl$/
end


module Gem::Security


  class Exception < Gem::Exception; end


  DIGEST_ALGORITHM =
    if defined?(OpenSSL::Digest) then
      OpenSSL::Digest::SHA1
    end


  DIGEST_NAME = # :nodoc:
    if DIGEST_ALGORITHM then
      DIGEST_ALGORITHM.new.name
    end


  KEY_ALGORITHM =
    if defined?(OpenSSL::PKey) then
      OpenSSL::PKey::RSA
    end


  KEY_LENGTH = 2048


  KEY_CIPHER = OpenSSL::Cipher.new('AES-256-CBC') if defined?(OpenSSL::Cipher)


  ONE_YEAR = 86400 * 365


  EXTENSIONS = {
    'basicConstraints'     => 'CA:FALSE',
    'keyUsage'             =>
      'keyEncipherment,dataEncipherment,digitalSignature',
    'subjectKeyIdentifier' => 'hash',
  }

  def self.alt_name_or_x509_entry certificate, x509_entry
    alt_name = certificate.extensions.find do |extension|
      extension.oid == "#{x509_entry}AltName"
    end

    return alt_name.value if alt_name

    #nodyna <send-2320> <SD MODERATE (change-prone variables)>
    certificate.send x509_entry
  end


  def self.create_cert subject, key, age = ONE_YEAR, extensions = EXTENSIONS,
                       serial = 1
    cert = OpenSSL::X509::Certificate.new

    cert.public_key = key.public_key
    cert.version    = 2
    cert.serial     = serial

    cert.not_before = Time.now
    cert.not_after  = Time.now + age

    cert.subject    = subject

    ef = OpenSSL::X509::ExtensionFactory.new nil, cert

    cert.extensions = extensions.map do |ext_name, value|
      ef.create_extension ext_name, value
    end

    cert
  end


  def self.create_cert_email email, key, age = ONE_YEAR, extensions = EXTENSIONS
    subject = email_to_name email

    extensions = extensions.merge "subjectAltName" => "email:#{email}"

    create_cert_self_signed subject, key, age, extensions
  end


  def self.create_cert_self_signed subject, key, age = ONE_YEAR,
                                   extensions = EXTENSIONS, serial = 1
    certificate = create_cert subject, key, age, extensions

    sign certificate, key, certificate, age, extensions, serial
  end


  def self.create_key length = KEY_LENGTH, algorithm = KEY_ALGORITHM
    algorithm.new length
  end


  def self.email_to_name email_address
    email_address = email_address.gsub(/[^\w@.-]+/i, '_')

    cn, dcs = email_address.split '@'

    dcs = dcs.split '.'

    name = "CN=#{cn}/#{dcs.map { |dc| "DC=#{dc}" }.join '/'}"

    OpenSSL::X509::Name.parse name
  end


  def self.re_sign expired_certificate, private_key, age = ONE_YEAR,
                   extensions = EXTENSIONS
    raise Gem::Security::Exception,
          "incorrect signing key for re-signing " +
          "#{expired_certificate.subject}" unless
      expired_certificate.public_key.to_pem == private_key.public_key.to_pem

    unless expired_certificate.subject.to_s ==
           expired_certificate.issuer.to_s then
      subject = alt_name_or_x509_entry expired_certificate, :subject
      issuer  = alt_name_or_x509_entry expired_certificate, :issuer

      raise Gem::Security::Exception,
            "#{subject} is not self-signed, contact #{issuer} " +
            "to obtain a valid certificate"
    end

    serial = expired_certificate.serial + 1

    create_cert_self_signed(expired_certificate.subject, private_key, age,
                            extensions, serial)
  end


  def self.reset
    @trust_dir = nil
  end


  def self.sign certificate, signing_key, signing_cert,
                age = ONE_YEAR, extensions = EXTENSIONS, serial = 1
    signee_subject = certificate.subject
    signee_key     = certificate.public_key

    alt_name = certificate.extensions.find do |extension|
      extension.oid == 'subjectAltName'
    end

    extensions = extensions.merge 'subjectAltName' => alt_name.value if
      alt_name

    issuer_alt_name = signing_cert.extensions.find do |extension|
      extension.oid == 'subjectAltName'
    end

    extensions = extensions.merge 'issuerAltName' => issuer_alt_name.value if
      issuer_alt_name

    signed = create_cert signee_subject, signee_key, age, extensions, serial
    signed.issuer = signing_cert.subject

    signed.sign signing_key, Gem::Security::DIGEST_ALGORITHM.new
  end


  def self.trust_dir
    return @trust_dir if @trust_dir

    dir = File.join Gem.user_home, '.gem', 'trust'

    @trust_dir ||= Gem::Security::TrustDir.new dir
  end


  def self.trusted_certificates &block
    trust_dir.each_certificate(&block)
  end


  def self.write pemmable, path, permissions = 0600, passphrase = nil, cipher = KEY_CIPHER
    path = File.expand_path path

    open path, 'wb', permissions do |io|
      if passphrase and cipher
        io.write pemmable.to_pem cipher, passphrase
      else
        io.write pemmable.to_pem
      end
    end

    path
  end

  reset

end

if defined?(OpenSSL::SSL) then
  require 'rubygems/security/policy'
  require 'rubygems/security/policies'
  require 'rubygems/security/trust_dir'
end

require 'rubygems/security/signer'

