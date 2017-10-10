class Lesstif < Formula
  desc "Open source implementation of OSF/Motif"
  homepage "http://lesstif.sourceforge.net"
  url "https://downloads.sourceforge.net/project/lesstif/lesstif/0.95.2/lesstif-0.95.2.tar.bz2"
  sha256 "eb4aa38858c29a4a3bcf605cfe7d91ca41f4522d78d770f69721e6e3a4ecf7e3"

  bottle do
    revision 1
    sha1 "50b1cecbfce9a66ae8253b6efe1ecef4c58678fc" => :yosemite
    sha1 "f6439fb1fda16afd5ae5447f071170b08a9484c3" => :mavericks
    sha1 "dff63d044e87b2137cf8f961f9c46186b7af18d1" => :mountain_lion
  end

  depends_on :x11
  depends_on "freetype"

  def install
    inreplace "configure", "`aclocal --print-ac-dir`", "#{share}/aclocal"

    ENV["LANG"] = "C"

    system "./configure", "--prefix=#{prefix}",
                          "--disable-debug",
                          "--enable-production",
                          "--disable-dependency-tracking",
                          "--enable-shared",
                          "--enable-static"

    system "make"

    ENV.deparallelize
    system "make", "install"
  end
end
