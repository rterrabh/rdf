class Mp3check < Formula
  desc "Tool to check mp3 files for consistency"
  homepage "https://code.google.com/p/mp3check/"
  url "https://mp3check.googlecode.com/files/mp3check-0.8.7.tgz"
  sha256 "27d976ad8495671e9b9ce3c02e70cb834d962b6fdf1a7d437bb0e85454acdd0e"

  def install
    ENV.deparallelize
    system "make"
    bin.install "mp3check"
  end
end
