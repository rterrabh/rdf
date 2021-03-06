class Nacl < Formula
  desc "Network communication, encryption, decryption, signatures library"
  homepage "http://nacl.cr.yp.to/"
  url "https://hyperelliptic.org/nacl/nacl-20110221.tar.bz2"
  mirror "https://mirrors.kernel.org/debian/pool/main/n/nacl/nacl_20110221.orig.tar.bz2"
  sha256 "4f277f89735c8b0b8a6bbd043b3efb3fa1cc68a9a5da6a076507d067fc3b3bf8"

  bottle do
    cellar :any
    sha1 "a2fd2a9f121f7c20dee040ae70cdd3e05708b98f" => :yosemite
    sha1 "ec947d17a2d50bca7e3ecd24ff24ef19481afac3" => :mavericks
    sha1 "074b5a2eda0007f256830e44314e55c152b6c03e" => :mountain_lion
  end

  def install
    system "./do" # This takes a while since it builds *everything*

    archstr  = Hardware.is_64_bit? ? "amd64" : "x86"
    hoststr  = `hostname | sed 's/\\..*//' | tr -cd '[a-z][A-Z][0-9]'`.strip

    include.install Dir["build/#{hoststr}/include/#{archstr}/crypto_*.h"]
    include.install "build/#{hoststr}/include/#{archstr}/randombytes.h"

    nacl_libdir = "build/#{hoststr}/lib/#{archstr}"
    system "ar", "-r", "#{nacl_libdir}/libnacl.a", "#{nacl_libdir}/randombytes.o"
    lib.install "#{nacl_libdir}/libnacl.a"
  end
end
