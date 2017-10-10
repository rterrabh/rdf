class Star < Formula
  desc "Standard tap archiver"
  homepage "http://cdrecord.org/private/star.html"
  url "https://downloads.sourceforge.net/project/s-tar/star-1.5.3.tar.bz2"
  sha256 "070342833ea83104169bf956aa880bcd088e7af7f5b1f8e3d29853b49b1a4f5b"

  depends_on "smake" => :build

  def install
    ENV.deparallelize # smake does not like -j

    system "smake", "GMAKE_NOWARN=true", "INS_BASE=#{prefix}", "INS_RBASE=#{prefix}", "install"

    (bin+"gnutar").unlink
    (bin+"tar").unlink
    (man1+"gnutar.1").unlink

    lib.rmtree
    include.rmtree

    %w[makefiles makerules].each { |f| (man5/"#{f}.5").unlink }
  end
end
