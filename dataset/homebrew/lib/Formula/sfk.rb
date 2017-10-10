class Sfk < Formula
  desc "Command Line Tools Collection"
  homepage "http://stahlworks.com/dev/swiss-file-knife.html"
  url "https://downloads.sourceforge.net/project/swissfileknife/1-swissfileknife/1.7.5/sfk-1.7.5.tar.gz"
  sha256 "f15b4bd974285138d857500ddf4563d8e77146ece967867944f09edb15e745c7"

  bottle do
    cellar :any
    sha256 "42ced5ac947ad0c40cc4f24ef19415ed349929687b89a41d1f558ccfe7d0f434" => :yosemite
    sha256 "ad2b87b8118e5c9c5dc6b41207430c29c9a55ca8058e1b8c4210045849398e8e" => :mavericks
    sha256 "40b99819db133c2b283375d9cd5a6854b962085e69def10e936fc0dff8cd2826" => :mountain_lion
  end

  def install
    system ENV.cxx, "-DMAC_OS_X", "sfk.cpp", "sfkext.cpp", "-o", "sfk"

    bin.install "sfk"
  end

  test do
    system "sfk", "ip"
  end
end
