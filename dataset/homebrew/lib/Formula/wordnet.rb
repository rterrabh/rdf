class Wordnet < Formula
  desc "Lexical database for the English language"
  homepage "http://wordnet.princeton.edu/"
  url "http://wordnetcode.princeton.edu/3.0/WordNet-3.0.tar.bz2"
  sha256 "6c492d0c7b4a40e7674d088191d3aa11f373bb1da60762e098b8ee2dda96ef22"
  version "3.1"

  depends_on :x11

  resource "dict" do
    url "http://wordnetcode.princeton.edu/wn3.1.dict.tar.gz"
    sha256 "3f7d8be8ef6ecc7167d39b10d66954ec734280b5bdcd57f7d9eafe429d11c22a"
    version "3.1"
  end

  def install
    (prefix/"dict").install resource("dict")

    ENV.append_to_cflags "-DUSE_INTERP_RESULT"
    system "./configure", "--disable-debug", "--disable-dependency-tracking",
                          "--prefix=#{prefix}",
                          "--mandir=#{man}"
    ENV.deparallelize
    system "make", "install"
  end
end
