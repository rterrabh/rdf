class Mpgtx < Formula
  desc "Toolbox to manipulate MPEG files"
  homepage "http://mpgtx.sourceforge.net"
  url "https://downloads.sourceforge.net/project/mpgtx/mpgtx/1.3.1/mpgtx-1.3.1.tar.gz"
  sha256 "8815e73e98b862f12ba1ef5eaaf49407cf211c1f668c5ee325bf04af27f8e377"

  def install
    system "./configure", "--parachute",
                          "--prefix=#{prefix}",
                          "--manprefix=#{man}"
    system "make", "LFLAGS="
    system "make install cpflags=RP"
  end
end
