class Tcptrack < Formula
  desc "Monitor status of TCP connections on a network interface"
  homepage "http://www.rhythm.cx/~steve/devel/tcptrack/"
  url "http://ftp.de.debian.org/debian/pool/main/t/tcptrack/tcptrack_1.4.2.orig.tar.gz"
  sha256 "6607b1e1c778c49d3e8795e119065cf66eb2db28b3255dbc56b1612527107049"

  def install
    ENV.libstdcxx
    inreplace "src/IPv6Address.cc", "s6_addr16", "__u6_addr.__u6_addr16"

    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"
    system "make", "install"
  end

  def caveats
    "Run tcptrack as root or via sudo in order for the program to obtain permissions on the network interface."
  end
end
