class RegexOpt < Formula
  desc "Perl-compatible regular expression optimizer"
  homepage "http://bisqwit.iki.fi/source/regexopt.html"
  url "http://bisqwit.iki.fi/src/arch/regex-opt-1.2.3.tar.gz"
  sha256 "e0a4e4fea7f46bd856ce946d5a57f2b19d742b5d6f486e054e4c51b1f534b87e"

  def install
    ENV.libstdcxx if ENV.compiler == :clang

    system "make", "CC=#{ENV.cc}", "CXX=#{ENV.cxx}"
    bin.install "regex-opt"
  end

  test do
    system "#{bin}/regex-opt"
  end
end
