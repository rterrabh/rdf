class Pngnq < Formula
  desc "Tool for optimizing PNG images"
  homepage "http://pngnq.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/pngnq/pngnq/1.1/pngnq-1.1.tar.gz"
  sha256 "c147fe0a94b32d323ef60be9fdcc9b683d1a82cd7513786229ef294310b5b6e2"
  revision 1

  depends_on "pkg-config" => :build
  depends_on "libpng"

  patch :DATA

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--prefix=#{prefix}"
    system "make", "install"
  end
end


__END__
diff --git a/src/rwpng.c b/src/rwpng.c
index aaa21fc..5324afe 100644
--- a/src/rwpng.c
+++ b/src/rwpng.c
@@ -31,6 +31,7 @@

+#include <zlib.h>

