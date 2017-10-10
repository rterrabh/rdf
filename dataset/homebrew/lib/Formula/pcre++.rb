class Pcrexx < Formula
  desc "C++ wrapper for the Perl Compatible Regular Expressions"
  homepage "http://www.daemon.de/PCRE"
  url "http://www.daemon.de/idisk/Apps/pcre++/pcre++-0.9.5.tar.gz"
  sha256 "77ee9fc1afe142e4ba2726416239ced66c3add4295ab1e5ed37ca8a9e7bb638a"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pcre"

  patch :DATA

  def install
    pcre = Formula["pcre"]
    system "autoreconf", "-fvi"
    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          "--with-pcre-lib=#{pcre.opt_lib}",
                          "--with-pcre-include=#{pcre.opt_include}"
    system "make", "install"

    mv man3/"Pcre.3", man3/"pcre++.3"
  end

  def caveats; <<-EOS.undent
    The man page has been renamed to pcre++.3 to avoid conflicts with
    pcre in case-insensitive file system.  Please use "man pcre++"
    instead.
    EOS
  end
end

__END__
diff --git a/libpcre++/pcre++.h b/libpcre++/pcre++.h
index d80b387..21869fc 100644
--- a/libpcre++/pcre++.h
+++ b/libpcre++/pcre++.h
@@ -47,11 +47,11 @@
+#include <clocale>
 
 
 extern "C" {
-  #include <locale.h>
 }
 
 namespace pcrepp {
