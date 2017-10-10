class Xmlto < Formula
  desc "Convert XML to another format (based on XSL or other tools)"
  homepage "https://fedorahosted.org/xmlto/"
  url "https://fedorahosted.org/releases/x/m/xmlto/xmlto-0.0.26.tar.bz2"
  sha256 "efb49b2fb3bc27c1a1e24fe34abf19b6bf6cbb40844e6fd58034cdf21c54b5ec"

  bottle do
    cellar :any
    sha1 "1135350e4d76f2a2b6c86fc8554aa9bb7d2ca7d7" => :yosemite
    sha1 "62c44bc17acaf2be24d10ada48b87d0d41fab60c" => :mavericks
    sha1 "752ba9e2f015a8da4b4ab4e082493d010d49db86" => :mountain_lion
  end

  depends_on "docbook"
  depends_on "docbook-xsl"
  depends_on "gnu-getopt"

  patch :DATA

  def install
    ENV["GETOPT"] = Formula["gnu-getopt"].opt_prefix/"bin/getopt"
    ENV["XML_CATALOG_FILES"] = "#{etc}/xml/catalog"

    ENV.deparallelize
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make", "install"
  end
end


__END__
--- xmlto-0.0.25/xmlto.in.orig
+++ xmlto-0.0.25/xmlto.in
@@ -209,7 +209,7 @@
 export VERBOSE
 
-XSLTOPTS="$XSLTOPTS --nonet"
+#XSLTOPTS="$XSLTOPTS --nonet"
 
 XSLTPARAMS=""
