class Wv < Formula
  desc "Programs for accessing Microsoft Word documents"
  homepage "http://wvware.sourceforge.net/"
  url "http://abisource.com/downloads/wv/1.2.9/wv-1.2.9.tar.gz"
  sha256 "4c730d3b325c0785450dd3a043eeb53e1518598c4f41f155558385dd2635c19d"

  depends_on "pkg-config" => :build
  depends_on "glib"
  depends_on "libgsf"
  depends_on "libwmf"
  depends_on "libpng"

  def install
    ENV.libxml2
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--mandir=#{man}"
    system "make"
    ENV.deparallelize

    bin.mkpath
    (lib/"pkgconfig").mkpath
    (include/"wv").mkpath
    man1.mkpath
    (share/"wv/wingdingfont").mkpath
    (share/"wv/patterns").mkpath

    system "make", "install"
  end
end
