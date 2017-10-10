class Libkml < Formula
  desc "Library to parse, generate and operate on KML"
  homepage "https://code.google.com/p/libkml/"

  stable do
    url "https://libkml.googlecode.com/files/libkml-1.2.0.tar.gz"
    sha256 "fae9085e4cd9f0d4ae0d0626be7acf4ad5cbb37991b9d886df29daf72df37cbc"

    patch do
      url "https://gist.githubusercontent.com/dakcarto/7419882/raw/10ae08af224b3fee0617fa6288d806d3ccf37c0f/libkml-1.2-static-deps"
      sha256 "c39995a1c1ebabc1692dc6be698d68e18170230d71d5a0ce426d8f41bdf0dc72"
    end
  end

  bottle do
    cellar :any
    revision 1
    sha1 "604dafcf5fb8135e89f4636af4ecb21b404b4e4b" => :yosemite
    sha1 "61000bffb52eb852149276e37b42461fd5f710a7" => :mavericks
    sha1 "68d01ed7b9748caa23f6309c62e836cb030f673d" => :mountain_lion
  end

  head do
    url "http://libkml.googlecode.com/svn/trunk/"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build

    patch do
      url "https://gist.githubusercontent.com/dakcarto/7420023/raw/65cdb088c91a7da844251e348eeda8df1d903f1d/libkml-svn-static-deps"
      sha1 "9ef82d73199325e63596c28c6965ec8c151bf7c5"
    end
  end

  patch :DATA

  def install
    if build.head?
      inreplace "configure.ac", "-Werror", ""

      system "./autogen.sh"
    end

    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end
end

__END__
diff --git a/src/kml/base/file_posix.cc b/src/kml/base/file_posix.cc
index 764ae55..8ee9892 100644
--- a/src/kml/base/file_posix.cc
+++ b/src/kml/base/file_posix.cc
@@ -29,6 +29,7 @@
+#include <unistd.h>
 
