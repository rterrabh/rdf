class CctoolsHeaders < Formula
  desc "cctools-headers via Apple"
  homepage "https://opensource.apple.com/"
  url "https://opensource.apple.com/tarballs/cctools/cctools-855.tar.gz"
  sha256 "751748ddf32c8ea84c175f32792721fa44424dad6acbf163f84f41e9617dbc58"

  keg_only :provided_by_osx

  resource "headers" do
    url "https://opensource.apple.com/tarballs/xnu/xnu-2422.90.20.tar.gz"
    sha256 "7bf3c6bc2f10b99e57b996631a7747b79d1e1684df719196db1e5c98a5585c23"
  end

  def install
    inreplace "include/Makefile", "/usr/include", "/include"
    system "make", "installhdrs", "DSTROOT=#{prefix}", "RC_ProjectSourceVersion=#{version}"
    (prefix/"usr").rmtree

    resource("headers").stage { (include/"mach").install "osfmk/mach/machine.h" }
  end
end
