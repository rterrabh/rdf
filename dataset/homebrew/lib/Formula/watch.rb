class Watch < Formula
  desc "Executes a program periodically, showing output fullscreen"
  homepage "http://sourceforge.net/projects/procps-ng/"
  url "http://download.sourceforge.net/project/procps-ng/Production/procps-ng-3.3.10.tar.xz"
  sha256 "a02e6f98974dfceab79884df902ca3df30b0e9bad6d76aee0fb5dce17f267f04"

  bottle do
    cellar :any
    sha1 "02dd29b9894a881d150ae369a0bd7e6c38517158" => :yosemite
    sha1 "4c879fbcd46a9867ec7a322ddbb466cb0a376825" => :mavericks
    sha1 "a7c559378bc74cd30d00f962e63d6ee5c705aea1" => :mountain_lion
  end

  conflicts_with "visionmedia-watch"

  def install
    system "./configure", "--disable-dependency-tracking", "--prefix=#{prefix}"

    system "make", "watch", "AM_LDFLAGS="
    bin.install "watch"
    man1.install "watch.1"
  end

  test do
    ENV["TERM"] = "xterm"
    system "#{bin}/watch", "--errexit", "--chgexit", "--interval", "1", "date"
  end
end
