class Readline < Formula
  desc "Library for command-line editing"
  homepage "https://tiswww.case.edu/php/chet/readline/rltop.html"
  url "http://ftpmirror.gnu.org/readline/readline-6.3.tar.gz"
  mirror "https://ftp.gnu.org/gnu/readline/readline-6.3.tar.gz"
  sha256 "56ba6071b9462f980c5a72ab0023893b65ba6debb4eeb475d7a563dc65cafd43"
  version "6.3.8"

  bottle do
    cellar :any
    sha1 "d8bec6237197bfff8535cd3ac10c18f2e4458a2a" => :yosemite
    sha1 "d530f4e966bb9c654a86f5cc0e65b20b1017aef2" => :mavericks
    sha1 "7473587d992d8c3eb37afe6c3e0adc3587c977f1" => :mountain_lion
    sha1 "e84f9cd95503b284651ef24bc8e7da30372687d3" => :lion
  end

  keg_only :shadowed_by_osx, <<-EOS.undent
    OS X provides the BSD libedit library, which shadows libreadline.
    In order to prevent conflicts when programs look for libreadline we are
    defaulting this GNU Readline installation to keg-only.
  EOS

  patch do
    url "https://gist.githubusercontent.com/jacknagel/d886531fb6623b60b2af/raw/746fc543e56bc37a26ccf05d2946a45176b0894e/readline-6.3.8.diff"
    sha256 "ef4fd6f24103b8f1d1199a6254d81a0cd63329bd2449ea9b93e66caf76d7ab89"
  end

  def install
    ENV.universal_binary
    system "./configure", "--prefix=#{prefix}", "--enable-multibyte"
    system "make", "install"

    lib.install_symlink "libhistory.6.3.dylib" => "libhistory.6.2.dylib",
                        "libreadline.6.3.dylib" => "libreadline.6.2.dylib"
  end

  test do
    (testpath/"test.c").write <<-EOS.undent

      int main()
      {
        printf("%s\\n", readline("test> "));
        return 0;
      }
    EOS
    system ENV.cc, "test.c", "-lreadline", "-o", "test"
    assert_equal "Hello, World!", pipe_output("./test", "Hello, World!\n").strip
  end
end
