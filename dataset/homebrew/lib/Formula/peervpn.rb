class Peervpn < Formula
  desc "Peer-to-peer VPN"
  homepage "http://www.peervpn.net"
  url "http://www.peervpn.net/files/peervpn-0-041.tar.gz"
  version "0.041"
  sha256 "94a7b649a973c1081d3bd9499bd7410b00b2afc5b4fd4341b1ccf2ce13ad8f52"

  bottle do
    cellar :any
    sha1 "b560c712976a84dfc0b84aec277becf0ab2aa930" => :mavericks
    sha1 "7af025a1bf74dcbd992f988d3e3ef9978445d860" => :mountain_lion
  end

  depends_on "openssl"
  depends_on :tuntap

  patch :DATA if MacOS.version == :snow_leopard

  def install
    system "make"
    bin.install "peervpn"
    etc.install "peervpn.conf"
  end

  def caveats; <<-EOS.undent
    To configure PeerVPN, edit:
    EOS
  end

  test do
    system "#{bin}/peervpn"
  end
end

__END__
diff --git a/platform/io.c b/platform/io.c
index 209666a..0a6c2cf 100644
--- a/platform/io.c
+++ b/platform/io.c
@@ -24,6 +24,16 @@
+size_t strnlen(const char *s, size_t maxlen)
+{
+        size_t len;
+
+        for (len = 0; len < maxlen; len++, s++) {
+                if (!*s)
+                        break;
+        }
+        return (len);
+}
