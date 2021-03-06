class Ncftp < Formula
  desc "FTP client with an advanced user interface"
  homepage "http://www.ncftp.com"
  url "ftp://ftp.ncftp.com/ncftp/ncftp-3.2.5-src.tar.gz"
  sha256 "ac111b71112382853b2835c42ebe7bd59acb7f85dd00d44b2c19fbd074a436c4"

  bottle do
    sha256 "50fb345b28bc8a20d2877d67108f87c9544568de9e27ae7a3545da3af3cb0b35" => :yosemite
    sha256 "07a73c0ac7005566895f7e42f4a1d1b8295a9cdc03ec7986028ae783313e428f" => :mavericks
    sha256 "e59965dc867f70420046475b30829cad0b334bc687e18362918fdfbab7521b59" => :mountain_lion
  end

  def install
    ENV.no_optimization
    system "./configure", "--disable-universal",
                          "--disable-precomp",
                          "--prefix=#{prefix}",
                          "--mandir=#{man}"
    system "make"
    system "make", "install"
  end

  test do
    system "#{bin}/ncftp", "-F"
  end
end
