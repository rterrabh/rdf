class Rhash < Formula
  desc "Utility for computing and verifying hash sums of files"
  homepage "http://rhash.anz.ru/"
  url "https://downloads.sourceforge.net/project/rhash/rhash/1.3.3/rhash-1.3.3-src.tar.gz"
  mirror "https://mirrors.kernel.org/debian/pool/main/r/rhash/rhash_1.3.3.orig.tar.gz"
  sha256 "5b520b597bd83f933d316fce1382bb90e0b0b87b559b8c9c9a197551c935315a"

  head "https://github.com/rhash/RHash.git"

  bottle do
    cellar :any
    sha256 "e957f797d99c99ad3ccba26cf960a1b2bfbf6915694b44496b8c899c322856ce" => :yosemite
    sha256 "f3a728fdbc481c60c42544e2360601e8bc8ed032b82c86a0e4f1e29949a2b653" => :mavericks
    sha256 "4d88312b2da6202c1929e5b586ed63780009d1467bdfef2cc6ec3c615e73ab42" => :mountain_lion
  end

  patch :DATA

  def install
    ENV.j1

    system "make", "lib-static", "lib-shared", "all", "CC=#{ENV.cc}"
    system "make", "install-lib-static", "install-lib-shared", "install",
                   "PREFIX=", "DESTDIR=#{prefix}", "CC=#{ENV.cc}"
  end

  test do
    (testpath/"test").write("test")
    (testpath/"test.sha1").write("a94a8fe5ccb19ba61c4c0873d391e987982fbbd3 test")
    system "#{bin}/rhash", "-c", "test.sha1"
  end
end

__END__
--- a/librhash/Makefile	2014-04-20 14:20:22.000000000 +0200
+++ b/librhash/Makefile	2014-04-20 14:40:02.000000000 +0200
@@ -26,8 +26,8 @@
 INCDIR  = $(PREFIX)/include
 LIBDIR  = $(PREFIX)/lib
 LIBRARY = librhash.a
-SONAME  = librhash.so.0
-SOLINK  = librhash.so
+SONAME  = librhash.0.dylib
+SOLINK  = librhash.dylib
 TEST_TARGET = test_hashes
 TEST_SHARED = test_shared
@@ -176,8 +176,7 @@

 $(SONAME): $(SOURCES)
-	sed -n '1s/.*/{ global:/p; s/^RHASH_API.* \([a-z0-9_]\+\)(.*/  \1;/p; $$s/.*/local: *; };/p' $(SO_HEADERS) > exports.sym
-	$(CC) -fpic $(ALLCFLAGS) -shared $(SOURCES) -Wl,--version-script,exports.sym,-soname,$(SONAME) $(LIBLDFLAGS) -o $@
+	$(CC) -fpic $(ALLCFLAGS) -dynamiclib $(SOURCES) $(LIBLDFLAGS) -Wl,-install_name,$(PREFIX)/lib/$@ -o $@
 	ln -s $(SONAME) $(SOLINK)
