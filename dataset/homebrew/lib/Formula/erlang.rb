class Erlang < Formula
  desc "Erlang Programming Language"
  homepage "http://www.erlang.org"

  stable do
    url "https://github.com/erlang/otp/archive/OTP-18.0.3.tar.gz"
    sha256 "3e1680aded824ad5659224024e09a4ff040e97a5b8ace4bdc1537b2f514a5a21"
  end

  head "https://github.com/erlang/otp.git"

  bottle do
    cellar :any
    sha256 "ad559514ac12544bee41b9a901c565913b0d24d17f7844265a10bb4d865e3985" => :yosemite
    sha256 "47a82e3384039029eb0344e052acd394873194034905d73a3b2514e5d7a90e49" => :mavericks
    sha256 "c86d7fdbd7db4e235e41ef26eedcc8aa309dcfb8e522a4246fb061fed08374db" => :mountain_lion
  end

  resource "man" do
    url "http://www.erlang.org/download/otp_doc_man_18.0.tar.gz"
    sha256 "e44f0ec36ee0683867bc2aa9cc7fbb020d9dfd57338f37b98dcd0771f5b95673"
  end

  resource "html" do
    url "http://www.erlang.org/download/otp_doc_html_18.0.tar.gz"
    sha256 "e5a766f68406f5025f921ec32e8959937189ed1245e24b03a74156a8898b03b2"
  end

  option "without-hipe", "Disable building hipe; fails on various OS X systems"
  option "with-native-libs", "Enable native library compilation"
  option "with-dirty-schedulers", "Enable experimental dirty schedulers"
  option "without-docs", "Do not install documentation"

  deprecated_option "disable-hipe" => "without-hipe"
  deprecated_option "no-docs" => "without-docs"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "openssl"
  depends_on "unixodbc" if MacOS.version >= :mavericks
  depends_on "fop" => :optional # enables building PDF docs
  depends_on "wxmac" => :recommended # for GUI apps like observer

  fails_with :llvm

  def install
    %w[LIBS FLAGS AFLAGS ZFLAGS].each { |k| ENV.delete("ERL_#{k}") }

    ENV["FOP"] = "#{HOMEBREW_PREFIX}/bin/fop" if build.with? "fop"

    system "./otp_build autoconf" if File.exist? "otp_build"

    args = %W[
      --disable-debug
      --disable-silent-rules
      --prefix=#{prefix}
      --enable-kernel-poll
      --enable-threads
      --enable-sctp
      --enable-dynamic-ssl-lib
      --with-ssl=#{Formula["openssl"].opt_prefix}
      --enable-shared-zlib
      --enable-smp-support
    ]

    args << "--enable-darwin-64bit" if MacOS.prefer_64_bit?
    args << "--enable-native-libs" if build.with? "native-libs"
    args << "--enable-dirty-schedulers" if build.with? "dirty-schedulers"
    args << "--enable-wx" if build.with? "wxmac"

    if MacOS.version >= :snow_leopard && MacOS::CLT.installed?
      args << "--with-dynamic-trace=dtrace"
    end

    if build.without? "hipe"
      args << "--disable-hipe"
    else
      args << "--enable-hipe"
    end

    system "./configure", *args
    system "make"
    ENV.j1 # Install is not thread-safe; can try to create folder twice and fail
    system "make", "install"

    if build.with? "docs"
      (lib/"erlang").install resource("man").files("man")
      doc.install resource("html")
    end
  end

  def caveats; <<-EOS.undent
    Man pages can be found in:

    Access them with `erl -man`, or add this directory to MANPATH.
    EOS
  end

  test do
    #nodyna <eval-588> <not yet classified>
    system "#{bin}/erl", "-noshell", "-eval", "crypto:start().", "-s", "init", "stop"
  end
end
