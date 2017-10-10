class Pyqt < Formula
  desc "Python bindings for Qt"
  homepage "http://www.riverbankcomputing.co.uk/software/pyqt"
  url "https://downloads.sf.net/project/pyqt/PyQt4/PyQt-4.11.3/PyQt-mac-gpl-4.11.3.tar.gz"
  sha256 "8b8bb3a2ef8b7368710e0bc59d6e94e1f513f7dbf10a3aaa3154f7b848c88b4d"

  bottle do
    sha1 "7d0b71a8c80401f6026172f22605e5a4e9eff8a3" => :yosemite
    sha1 "455a2cc8c46f64b2d27d2248b3bd6387e345377f" => :mavericks
    sha1 "30c74d1bfad2bc16c0052fd767fdb21b461e41e6" => :mountain_lion
  end

  option "without-python", "Build without python 2 support"
  depends_on :python3 => :optional

  if build.without?("python3") && build.without?("python")
    odie "pyqt: --with-python3 must be specified when using --without-python"
  end

  depends_on "qt"

  if build.with? "python3"
    depends_on "sip" => "with-python3"
  else
    depends_on "sip"
  end

  def install
    if ENV.compiler == :clang && MacOS.version >= :mavericks
      ENV.append "QMAKESPEC", "unsupported/macx-clang-libc++"
    end

    Language::Python.each_python(build) do |python, version|
      ENV.append_path "PYTHONPATH", "#{Formula["sip"].opt_lib}/python#{version}/site-packages"

      args = ["--confirm-license",
              "--bindir=#{bin}",
              "--destdir=#{lib}/python#{version}/site-packages",
              "--sipdir=#{share}/sip"]


      require "tmpdir"
      dir = Dir.mktmpdir
      begin
        cp_r(Dir.glob("*"), dir)
        cd dir do
          system python, "configure.py", *args
          (lib/"python#{version}/site-packages/PyQt4").install "pyqtconfig.py"
        end
      ensure
        remove_entry_secure dir
      end

      if ENV.compiler == :clang && MacOS.version >= :mavericks
        args << "--spec" << "unsupported/macx-clang-libc++"
      end

      system python, "configure-ng.py", *args
      system "make"
      system "make", "install"
      system "make", "clean"  # for when building against multiple Pythons
    end
  end

  def caveats
    "Phonon support is broken."
  end

  test do
    Pathname("test.py").write <<-EOS.undent
      from PyQt4 import QtNetwork
      QtNetwork.QNetworkAccessManager().networkAccessible()
    EOS

    Language::Python.each_python(build) do |python, _version|
      system python, "test.py"
    end
  end
end
