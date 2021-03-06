class Swfmill < Formula
  desc "xml2swf and swf2xml processor"
  homepage "http://swfmill.org"
  url "http://swfmill.org/releases/swfmill-0.3.3.tar.gz"
  sha256 "f9e8529eed84962abf88c6457b59cbc6d230db068d1fdd977e7b234228beac96"
  revision 1

  depends_on "pkg-config" => :build
  depends_on "freetype"
  depends_on "libpng"

  def install
    inreplace "src/swft/swft_import_ttf.cpp",
      "#include <freetype/tttables.h>",
      "#include FT_TRUETYPE_TABLES_H"

    system "./configure", "--prefix=#{prefix}"
    system "make", "LIBS=-lz", "install"
  end
end
