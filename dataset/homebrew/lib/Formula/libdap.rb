class Libdap < Formula
  desc "Framework for scientific data networking"
  homepage "http://www.opendap.org"
  url "http://www.opendap.org/pub/source/libdap-3.12.1.tar.gz"
  sha256 "10926129fefa9cb7050a7e501f3dc5c75b63709196b2c9e1e158b28b2dc098f2"
  revision 1

  bottle do
    sha1 "65bc997be2aea798c980242f10e153ae9740ff31" => :yosemite
    sha1 "ef2af8ad1095871810890fa3a2c81574ca9cbd66" => :mavericks
    sha1 "b633edaa59670669c726b1a6642eebfcf530f671" => :mountain_lion
  end

  depends_on "pkg-config" => :build
  depends_on "libxml2"

  def install
    system "./configure",
           "--disable-debug",
           "--disable-dependency-tracking",
           "--prefix=#{prefix}",
           "--with-curl=/usr",
           "--with-included-regex"

    system "make", "install"
  end
end
