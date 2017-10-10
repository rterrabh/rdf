class Libtorrent < Formula
  desc "BitTorrent library"
  homepage "https://github.com/rakshasa/libtorrent"
  url "https://mirrors.ocf.berkeley.edu/debian/pool/main/libt/libtorrent/libtorrent_0.13.4.orig.tar.gz"
  mirror "https://mirrors.kernel.org/debian/pool/main/libt/libtorrent/libtorrent_0.13.4.orig.tar.gz"
  sha256 "74a193d0e91a26f9471c12424596e03b82413d0dd0e1c8d4d7dad25a01cc60e5"

  def pour_bottle?
    false
  end

  depends_on "pkg-config" => :build
  depends_on "openssl"

  fails_with :clang do
    cause "Causes segfaults at startup/at random."
  end

  def install
    ENV.libstdcxx if ENV.compiler == :clang

    system "./configure", "--prefix=#{prefix}",
                          "--disable-debug",
                          "--disable-dependency-tracking",
                          "--with-kqueue",
                          "--enable-ipv6"
    system "make"
    system "make", "install"
  end
end
