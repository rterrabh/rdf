class Ngrok < Formula
  desc "Expose localhost to the internet and capture traffic for replay"
  homepage "https://ngrok.com"
  head "https://github.com/inconshreveable/ngrok.git"
  url "https://github.com/inconshreveable/ngrok/archive/1.7.1.tar.gz"
  sha256 "ffb1ad90d5aa3c8b3a9bfd8109a71027645a78d5e61fccedd0873fee060da665"

  bottle do
    cellar :any
    sha256 "d626cc4d60628236e13c4a7e4e9f66f73b9a9d865178006fc16327c29ead2bbf" => :yosemite
    sha256 "a4c522524765cdb27fe6b531c0694cad70bdf21bf42f4ded4a95e8822f2a482c" => :mavericks
    sha256 "ede711ae53e7a26d249657461101a1cfb9c5cd7c3dc602e3091a2579a87b59aa" => :mountain_lion
  end

  depends_on "go" => :build
  depends_on :hg => :build

  def install
    ENV.j1
    system "make", "release-client"
    bin.install "bin/ngrok"
  end

  test do
    system "#{bin}/ngrok", "version"
  end
end
