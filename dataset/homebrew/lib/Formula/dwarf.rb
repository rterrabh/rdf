class Dwarf < Formula
  desc "Object file manipulation tool"
  homepage "https://code.google.com/p/dwarf-ng/"
  url "https://dwarf-ng.googlecode.com/files/dwarf-0.3.0.tar.gz"
  sha256 "85062d0d3e8aa31374dd085cb79ce02c2b8737e9b143f640a262556233715763"

  depends_on "readline"

  fails_with :clang do
    cause "error: unknown type name 'intmax_t'"
  end

  fails_with :gcc => "5"

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-dependency-tracking"
    system "make", "install"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dwarf --help", 1)
  end
end
