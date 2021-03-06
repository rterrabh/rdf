
class Itex2mml < Formula
  desc "Text filter to convert itex equations to MathML"
  homepage "http://golem.ph.utexas.edu/~distler/blog/itex2MML.html"
  url "http://golem.ph.utexas.edu/~distler/blog/files/itexToMML-1.5.1.tar.gz"
  sha256 "09f39f9db83d2693c9c80288644a8121cd268e956e44684722d29cd6343f524c"

  def install
    bin.mkpath
    cd "itex-src" do
      system "make"
      system "make", "install", "prefix=#{prefix}", "BINDIR=#{bin}"
    end
  end

  test do
    system "#{bin}/itex2MML", "--version"
  end
end
