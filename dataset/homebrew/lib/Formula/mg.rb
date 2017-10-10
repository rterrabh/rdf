class Mg < Formula
  desc "Small Emacs-like editor"
  homepage "http://homepage.boetes.org/software/mg/"
  url "http://homepage.boetes.org/software/mg/mg-20131118.tar.gz"
  sha256 "b99fe10cb8473e035ff43bf3fbf94a24035e4ebb89484d48e5b33075d22d79f3"

  depends_on "clens"

  def install
    inreplace "GNUmakefile", "$(includedir)/clens", "#{Formula["clens"].opt_include}/clens"

    system "make"
    bin.install "mg"
    doc.install "tutorial"
    man1.install "mg.1"
  end
end
