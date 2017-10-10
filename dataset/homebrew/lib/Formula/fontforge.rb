class Fontforge < Formula
  desc "Command-line outline and bitmap font editor/converter"
  homepage "https://fontforge.github.io"
  url "https://github.com/fontforge/fontforge/archive/20150824.tar.gz"
  sha256 "28ab2471cb010c1fa75b8ab8191a1dded81fe1e9490aa5ff6ab4706a4c78ff27"
  head "https://github.com/fontforge/fontforge.git"

  bottle do
    revision 1
    sha256 "f8228c12d9bcda768334b32b51251edd9c970e6a6f213896b7d74e8dfa96231d" => :yosemite
    sha256 "b303e97388537aa75f15e4f9f16d84470b4f6fa9aaa2b2cb151a6b288903886c" => :mavericks
    sha256 "065e2c82a000ed3d07f6ac8edc41b530b99f81b10c42442b3887daa5007223cb" => :mountain_lion
  end

  option "with-giflib", "Build with GIF support"
  option "with-extra-tools", "Build with additional font tools"

  deprecated_option "with-gif" => "with-giflib"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "pkg-config" => :build
  depends_on "libtool" => :run
  depends_on "gettext"
  depends_on "pango"
  depends_on "zeromq"
  depends_on "czmq"
  depends_on "cairo"
  depends_on "libpng" => :recommended
  depends_on "jpeg" => :recommended
  depends_on "libtiff" => :recommended
  depends_on "giflib" => :optional
  depends_on "libspiro" => :optional
  depends_on :python if MacOS.version <= :snow_leopard

  depends_on "fontconfig"

  resource "gnulib" do
    url "git://git.savannah.gnu.org/gnulib.git",
        :revision => "9a417cf7d48fa231c937c53626da6c45d09e6b3e"
  end

  fails_with :llvm do
    build 2336
    cause "Compiling cvexportdlg.c fails with error: initializer element is not constant"
  end

  def install
    ENV["PYTHON_CFLAGS"] = `python-config --cflags`.chomp
    ENV["PYTHON_LIBS"] = "-undefined dynamic_lookup"
    python_libs = `python2.7-config --ldflags`.chomp
    inreplace "fontforgeexe/Makefile.am" do |s|
      oldflags = s.get_make_var "libfontforgeexe_la_LDFLAGS"
      s.change_make_var! "libfontforgeexe_la_LDFLAGS", "#{python_libs} #{oldflags}"
    end

    inreplace "configure.ac", 'test "y$HOMEBREW_BREW_FILE" != "y"', "false"

    args = %W[
      --prefix=#{prefix}
      --disable-silent-rules
      --disable-dependency-tracking
      --with-pythonbinary=#{which "python2.7"}
      --without-x
    ]

    args << "--without-libpng" if build.without? "libpng"
    args << "--without-libjpeg" if build.without? "jpeg"
    args << "--without-libtiff" if build.without? "libtiff"
    args << "--without-giflib" if build.without? "giflib"
    args << "--without-libspiro" if build.without? "libspiro"

    ENV.append "LDFLAGS", "-lintl"

    ENV["ARCHFLAGS"] = "-arch #{MacOS.preferred_arch}"

    resource("gnulib").fetch
    system "./bootstrap",
           "--gnulib-srcdir=#{resource("gnulib").cached_download}",
           "--skip-git"
    system "./configure", *args
    system "make"
    system "make", "install"

    (share/"fontforge/osx/FontForge.app").rmtree

    if build.with? "extra-tools"
      cd "contrib/fonttools" do
        system "make"
        bin.install Dir["*"].select { |f| File.executable? f }
      end
    end
  end

  test do
    system bin/"fontforge", "-version"
    system "python", "-c", "import fontforge"
  end
end
