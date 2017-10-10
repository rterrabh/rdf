class Litmus < Formula
  desc "WebDAV server protocol compliance test suite"
  homepage "http://www.webdav.org/neon/litmus/"
  url "http://www.webdav.org/neon/litmus/litmus-0.13.tar.gz"
  sha256 "09d615958121706444db67e09c40df5f753ccf1fa14846fdeb439298aa9ac3ff"

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end
end
