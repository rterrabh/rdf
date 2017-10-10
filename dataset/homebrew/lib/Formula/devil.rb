class Devil < Formula
  desc "Cross-platform image library"
  homepage "http://sourceforge.net/projects/openil/"
  url "https://downloads.sourceforge.net/project/openil/DevIL/1.7.8/DevIL-1.7.8.tar.gz"
  sha256 "682ffa3fc894686156337b8ce473c954bf3f4fb0f3ecac159c73db632d28a8fd"
  revision 1

  depends_on "libpng"
  depends_on "jpeg"

  option :universal

  fails_with :clang do
    cause "invalid -std=gnu99 flag while building C++"
  end

  fails_with :gcc => "5"

  patch :DATA

  def install
    ENV.universal_binary if build.universal?

    system "./configure", "--disable-debug",
                          "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--enable-ILU",
                          "--enable-ILUT"
    system "make", "install"
  end
end

__END__
--- a/src-ILU/ilur/ilur.c   2009-03-08 08:10:12.000000000 +0100
+++ b/src-ILU/ilur/ilur.c  2010-09-26 20:01:45.000000000 +0200
@@ -1,6 +1,7 @@
-#include <malloc.h>
+#include <stdlib.h>
+#include "sys/malloc.h"


