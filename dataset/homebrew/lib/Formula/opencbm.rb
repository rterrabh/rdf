class Opencbm < Formula
  desc "Provides access to various floppy drive formats"
  homepage "http://www.trikaliotis.net/opencbm-alpha"
  url "http://www.trikaliotis.net/Download/opencbm-0.4.99.97/opencbm-0.4.99.97.tar.bz2"
  sha256 "f67c47470181bec2faea45ad2ac82ae237f30ad54c406b0e7dd1a4ad97b16d87"
  head "git://git.code.sf.net/p/opencbm/code"

  depends_on "cc65" => :build
  depends_on "libusb-compat"

  def install
    ENV.deparallelize

    args = %W[
      -fLINUX/Makefile
      LIBUSB_CONFIG=#{Formula["libusb-compat"].bin}/libusb-config
      PREFIX=#{prefix}
      MANDIR=#{man1}
    ]

    cd "opencbm" do
      system "make", *args
      system "make", "install-all", *args
    end
  end

  test do
    system "#{bin}/cbmctrl", "--help"
  end
end
