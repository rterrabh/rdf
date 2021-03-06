class Stunnel < Formula
  desc "SSL tunneling program"
  homepage "https://www.stunnel.org/"
  url "https://www.stunnel.org/downloads/stunnel-5.22.tar.gz"
  mirror "https://www.usenix.org.uk/mirrors/stunnel/stunnel-5.22.tar.gz"
  sha256 "8ad628a6948153cdb2044283f6988384a30585ea7e14778c2ee616a6678cb83f"

  bottle do
    sha256 "be4ee6b09e1d397537d21fd2e453ce95b82b533484653174a3b113d88e520b85" => :yosemite
    sha256 "e5279aa80436f63cc7a921e222100b8834e56cc5f19f592354ac125770c7379b" => :mavericks
    sha256 "af4e77c71b62378eed6ab447346522b7953034aae7dd4bbce2033b29ed8d3bad" => :mountain_lion
  end

  depends_on "openssl"

  def install
    stunnel_cnf = Pathname.new("tools/stunnel.cnf")
    stunnel_cnf.unlink
    stunnel_cnf.write <<-EOS.undent

      [ req ]
      default_bits                    = 2048
      encrypt_key                     = no
      distinguished_name              = req_dn
      x509_extensions                 = cert_type
      prompt                          = no

      [ req_dn ]
      countryName                     = PL
      stateOrProvinceName             = Mazovia Province
      localityName                    = Warsaw
      organizationName                = Stunnel Developers
      organizationalUnitName          = Provisional CA
      0.commonName                    = localhost


      [ cert_type ]
      nsCertType                      = server
    EOS

    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--localstatedir=#{var}",
                          "--mandir=#{man}",
                          "--disable-libwrap",
                          "--disable-systemd",
                          "--with-ssl=#{Formula["openssl"].opt_prefix}"
    system "make", "install", "cert"
  end

  def caveats
    <<-EOS.undent
      A bogus SSL server certificate has been installed to:

      This certificate will be used by default unless a config file says otherwise!
      Stunnel will refuse to load the sample configuration file if left unedited.

      In your stunnel configuration, specify a SSL certificate with
      the "cert =" option for each service.
    EOS
  end

  test do
    (testpath/"tstunnel.conf").write <<-EOS.undent
      cert = #{etc}/stunnel/stunnel.pem

      setuid = nobody
      setgid = nobody

      [pop3s]
      accept  = 995
      connect = 110

      [imaps]
      accept  = 993
      connect = 143
    EOS

    assert_match /successful/, pipe_output("#{bin}/stunnel #{testpath}/tstunnel.conf 2>&1")
  end
end
