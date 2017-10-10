class OracleHomeVarRequirement < Requirement
  fatal true
  satisfy(:build_env => false) { ENV["ORACLE_HOME"] }

  def message; <<-EOS.undent
      To use --with-oci you have to set the ORACLE_HOME environment variable.
      Check Oracle Instant Client documentation for more information.
    EOS
  end
end

class Qt5 < Formula
  desc "Version 5 of the Qt framework"
  homepage "https://www.qt.io/"
  head "https://code.qt.io/qt/qt5.git", :branch => "5.5", :shallow => false

  stable do
    url "https://download.qt.io/official_releases/qt/5.5/5.5.0/single/qt-everywhere-opensource-src-5.5.0.tar.xz"
    mirror "https://www.mirrorservice.org/sites/download.qt-project.org/official_releases/qt/5.5/5.5.0/single/qt-everywhere-opensource-src-5.5.0.tar.xz"
    sha256 "7ea2a16ecb8088e67db86b0835b887d5316121aeef9565d5d19be3d539a2c2af"

    patch :DATA

    if MacOS.version >= :el_capitan
      patch do
        url "https://raw.githubusercontent.com/DomT4/scripts/2107043e8/Homebrew_Resources/Qt5/qt5_el_capitan.diff"
        sha256 "bd8fd054247ec730f60778e210d58cba613265e5df04ec93f4110421fb03b14a"
      end
    end
  end

  bottle do
    sha256 "3f334cdb65ea7ab4255abfd254f08cf095b3ba2c9f1e403afe6236975a88b160" => :yosemite
    sha256 "9bef8bea9a731fc5b26434f817858931442783c8a4a62bf4dc95fa6944550ed8" => :mavericks
    sha256 "946991e0aa83dfb119e9ed306a61645b9648537212758477db7772179f7503e4" => :mountain_lion
  end

  keg_only "Qt 5 conflicts Qt 4 (which is currently much more widely used)."

  option :universal
  option "with-docs", "Build documentation"
  option "with-examples", "Build examples"
  option "with-developer", "Build and link with developer options"
  option "with-oci", "Build with Oracle OCI plugin"

  deprecated_option "developer" => "with-developer"
  deprecated_option "qtdbus" => "with-d-bus"

  depends_on :macos => :lion
  depends_on "pkg-config" => :build
  depends_on "d-bus" => :optional
  depends_on :mysql => :optional
  depends_on :xcode => :build

  depends_on OracleHomeVarRequirement if build.with? "oci"

  def install
    ENV.universal_binary if build.universal?

    args = ["-prefix", prefix,
            "-system-zlib", "-securetransport",
            "-qt-libpng", "-qt-libjpeg",
            "-no-rpath", "-no-openssl",
            "-confirm-license", "-opensource",
            "-nomake", "tests", "-release"]

    args << "-nomake" << "examples" if build.without? "examples"

    args << "-plugin-sql-mysql" if build.with? "mysql"

    if build.with? "d-bus"
      dbus_opt = Formula["d-bus"].opt_prefix
      args << "-I#{dbus_opt}/lib/dbus-1.0/include"
      args << "-I#{dbus_opt}/include/dbus-1.0"
      args << "-L#{dbus_opt}/lib"
      args << "-ldbus-1"
      args << "-dbus-linked"
    end

    if MacOS.prefer_64_bit? || build.universal?
      args << "-arch" << "x86_64"
    end

    if !MacOS.prefer_64_bit? || build.universal?
      args << "-arch" << "x86"
    end

    if build.with? "oci"
      args << "-I#{ENV["ORACLE_HOME"]}/sdk/include"
      args << "-L#{ENV["ORACLE_HOME"]}"
      args << "-plugin-sql-oci"
    end

    args << "-developer-build" if build.with? "developer"

    system "./configure", *args
    system "make"
    ENV.j1
    system "make", "install"

    if build.with? "docs"
      system "make", "docs"
      system "make", "install_docs"
    end

    frameworks.install_symlink Dir["#{lib}/*.framework"]

    Pathname.glob("#{lib}/*.framework/Headers") do |path|
      include.install_symlink path => path.parent.basename(".framework")
    end

    inreplace prefix/"mkspecs/qconfig.pri", /\n\n# pkgconfig/, ""
    inreplace prefix/"mkspecs/qconfig.pri", /\nPKG_CONFIG_.*=.*$/, ""

    Pathname.glob("#{bin}/*.app") { |app| mv app, prefix }
  end

  def caveats; <<-EOS.undent
    We agreed to the Qt opensource license for you.
    If this is unacceptable you should uninstall.
    EOS
  end

  test do
    (testpath/"hello.pro").write <<-EOS.undent
      QT       += core
      QT       -= gui
      TARGET = hello
      CONFIG   += console
      CONFIG   -= app_bundle
      TEMPLATE = app
      SOURCES += main.cpp
    EOS

    (testpath/"main.cpp").write <<-EOS.undent

      int main(int argc, char *argv[])
      {
        QCoreApplication a(argc, argv);
        qDebug() << "Hello World!";
        return 0;
      }
    EOS

    system bin/"qmake", testpath/"hello.pro"
    system "make"
    assert File.exist?("hello")
    assert File.exist?("main.o")
    system "./hello"
  end
end

__END__
diff --git a/qtbase/src/corelib/global/qcompilerdetection.h b/qtbase/src/corelib/global/qcompilerdetection.h
index 7ff1b67..060af29 100644
--- a/qtbase/src/corelib/global/qcompilerdetection.h
+++ b/qtbase/src/corelib/global/qcompilerdetection.h
@@ -155,7 +155,7 @@
 /* Clang also masquerades as GCC */
-#      if __apple_build_version__ >= 6020049
+#      if __apple_build_version__ >= 7000053
