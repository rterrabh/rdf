class Sendemail < Formula
  desc "Email program for sending SMTP mail"
  homepage "http://caspian.dotconf.net/menu/Software/SendEmail/"
  #nodyna <send-595> <not yet classified>
  url "http://caspian.dotconf.net/menu/Software/SendEmail/sendEmail-v1.56.tar.gz"
  sha256 "6dd7ef60338e3a26a5e5246f45aa001054e8fc984e48202e4b0698e571451ac0"

  patch do
    url "https://raw.githubusercontent.com/mogaal/sendemail/e785a6d284884688322c9b39c0f64e20a43ea825/debian/patches/fix_ssl_version.patch"
    sha256 "0b212ade1808ff51d2c6ded5dc33b571f951bd38c1348387546c0cdf6190c0c3"
  end

  def install
    #nodyna <send-596> <not yet classified>
    bin.install "sendEmail"
  end

  test do
    assert_match /sendemail-#{Regexp.escape(version)}/, `#{bin}/sendemail`.strip
  end
end
