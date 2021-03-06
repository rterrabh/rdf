class Libsamplerate < Formula
  desc "Library for sample rate conversion of audio data"
  homepage "http://www.mega-nerd.com/SRC"
  url "http://www.mega-nerd.com/SRC/libsamplerate-0.1.8.tar.gz"
  sha256 "93b54bdf46d5e6d2354b7034395fe329c222a966790de34520702bb9642f1c06"

  bottle do
    cellar :any
    revision 1
    sha1 "7bdee60fa49e368546369cafdbff37a772970492" => :yosemite
    sha1 "a60d3e18f126fe69826cd8e4ab9944574e1ac9b6" => :mavericks
    sha1 "64fd25bc4134aa6f3d3d463892c662e0e73bc333" => :mountain_lion
  end

  depends_on "pkg-config" => :build
  depends_on "libsndfile" => :optional
  depends_on "fftw" => :optional

  patch :DATA

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make", "install"
  end
end

__END__
--- a/examples/audio_out.c	2011-07-12 16:57:31.000000000 -0700
+++ b/examples/audio_out.c	2012-03-11 20:48:57.000000000 -0700
@@ -168,7 +168,7 @@
 
 
-#include <Carbon.h>
+#include <Carbon/Carbon.h>
 
