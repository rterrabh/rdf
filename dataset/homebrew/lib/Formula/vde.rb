class Vde < Formula
  desc "Ethernet compliant virtual network"
  homepage "http://vde.sourceforge.net/"
  url "https://downloads.sourceforge.net/project/vde/vde2/2.3.2/vde2-2.3.2.tar.gz"
  sha256 "22df546a63dac88320d35d61b7833bbbcbef13529ad009c7ce3c5cb32250af93"

  def install
    system "./configure", "--prefix=#{prefix}"
    ENV.j1
    system "make", "install"
  end
end
