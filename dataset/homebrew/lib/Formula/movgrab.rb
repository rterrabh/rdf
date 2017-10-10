class Movgrab < Formula
  desc "Downloader for youtube, dailymotion, and other video websites"
  homepage "https://sites.google.com/site/columscode/home/movgrab"
  url "https://sites.google.com/site/columscode/files/movgrab-1.2.1.tar.gz"
  sha256 "1e9a57b1c934d8584f9133d918c1ceecfe102bbaf9fb4c8ab174a642917ae4a8"

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking"
    system "make"

    system "rm INSTALL"
    system "make", "install"
  end
end
