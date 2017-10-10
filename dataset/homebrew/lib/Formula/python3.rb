class Python3 < Formula
  desc "Interpreted, interactive, object-oriented programming language"
  homepage "https://www.python.org/"
  url "https://www.python.org/ftp/python/3.4.3/Python-3.4.3.tar.xz"
  sha256 "b5b3963533768d5fc325a4d7a6bd6f666726002d696f1d399ec06b043ea996b8"
  revision 2

  bottle do
    revision 1
    sha256 "56a1b3a22e73fc804c26b2c6cab9f19a4f8db52958d8f74affd5e2d322b9ecb1" => :yosemite
    sha256 "913a4b5dda0a07107f7ad10a051615689d2f534abd92fb6d853dfe1339c0920b" => :mavericks
    sha256 "5d9fc73a5ed4754be0bcb0efd7f639dc95a9ea86bae87c86fb6358294c45c8db" => :mountain_lion
  end

  head "https://hg.python.org/cpython", :using => :hg

  devel do
    url "https://www.python.org/ftp/python/3.5.0/Python-3.5.0rc1.tgz"
    sha256 "af300225b740401aaa3cb741568cd8a12fdb870b5f395ef8b1015dd45a6330bf"
  end

  option :universal
  option "with-tcl-tk", "Use Homebrew's Tk instead of OS X Tk (has optional Cocoa and threads support)"
  option "with-quicktest", "Run `make quicktest` after the build"

  deprecated_option "quicktest" => "with-quicktest"
  deprecated_option "with-brewed-tk" => "with-tcl-tk"

  depends_on "pkg-config" => :build
  depends_on "readline" => :recommended
  depends_on "sqlite" => :recommended
  depends_on "gdbm" => :recommended
  depends_on "openssl"
  depends_on "xz" => :recommended  # for the lzma module added in 3.3
  depends_on "homebrew/dupes/tcl-tk" => :optional
  depends_on :x11 if build.with?("tcl-tk") && Tab.for_name("homebrew/dupes/tcl-tk").with?("x11")

  skip_clean "bin/pip3", "bin/pip-3.4", "bin/pip-3.5"
  skip_clean "bin/easy_install3", "bin/easy_install-3.4", "bin/easy_install-3.5"

  resource "setuptools" do
    url "https://pypi.python.org/packages/source/s/setuptools/setuptools-18.1.tar.gz"
    sha256 "ad52a9d5b3a6f39c2a1c2deb96cc4f6aff29d6511bdea2994322c40b60c9c36a"
  end

  resource "pip" do
    url "https://pypi.python.org/packages/source/p/pip/pip-7.1.0.tar.gz"
    sha256 "d5275ba3221182a5dd1b6bcfbfc5ec277fb399dd23226d6fa018048f7e0f10f2"
  end

  resource "wheel" do
    url "https://pypi.python.org/packages/source/w/wheel/wheel-0.24.0.tar.gz"
    sha256 "ef832abfedea7ed86b6eae7400128f88053a1da81a37c00613b1279544d585aa"
  end

  patch :DATA if build.with? "tcl-tk"

  def lib_cellar
    prefix/"Frameworks/Python.framework/Versions/#{xy}/lib/python#{xy}"
  end

  def site_packages_cellar
    lib_cellar/"site-packages"
  end

  def site_packages
    HOMEBREW_PREFIX/"lib/python#{xy}/site-packages"
  end

  fails_with :llvm do
    build 2336
    cause <<-EOS.undent
      Could not find platform dependent libraries <exec_prefix>
      Consider setting $PYTHONHOME to <prefix>[:<exec_prefix>]
      python.exe(14122) malloc: *** mmap(size=7310873954244194304) failed (error code=12)
      *** error: can't allocate region
      *** set a breakpoint in malloc_error_break to debug
      Could not import runpy module
      make: *** [pybuilddir.txt] Segmentation fault: 11
    EOS
  end

  def pour_bottle?
    MacOS::CLT.installed?
  end

  def install
    ENV["PYTHONHOME"] = nil
    ENV["PYTHONPATH"] = nil

    args = %W[
      --prefix=#{prefix}
      --enable-ipv6
      --datarootdir=#{share}
      --datadir=#{share}
      --enable-framework=#{frameworks}
      --without-ensurepip
    ]

    args << "--without-gcc" if ENV.compiler == :clang

    unless MacOS::CLT.installed?
      cflags = "CFLAGS=-isysroot #{MacOS.sdk_path}"
      ldflags = "LDFLAGS=-isysroot #{MacOS.sdk_path}"
      args << "CPPFLAGS=-I#{MacOS.sdk_path}/usr/include" # find zlib
      if build.without? "tcl-tk"
        cflags += " -I#{MacOS.sdk_path}/System/Library/Frameworks/Tk.framework/Versions/8.5/Headers"
      end
      args << cflags
      args << ldflags
    end
    args << "MACOSX_DEPLOYMENT_TARGET=#{MacOS.version}"

    inreplace "setup.py" do |s|
      s.gsub! "do_readline = self.compiler.find_library_file(lib_dirs, 'readline')",
              "do_readline = '#{Formula["readline"].opt_lib}/libhistory.dylib'"
      s.gsub! "/usr/local/ssl", Formula["openssl"].opt_prefix
    end

    if build.universal?
      ENV.universal_binary
      args << "--enable-universalsdk" << "--with-universal-archs=intel"
    end

    inreplace("setup.py", 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', "pass") if build.with? "sqlite"

    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! "DEFAULT_LIBRARY_FALLBACK = [", "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      f.gsub! "DEFAULT_FRAMEWORK_FALLBACK = [", "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    if build.with? "tcl-tk"
      tcl_tk = Formula["tcl-tk"].opt_prefix
      ENV.append "CPPFLAGS", "-I#{tcl_tk}/include"
      ENV.append "LDFLAGS", "-L#{tcl_tk}/lib"
    end

    system "./configure", *args

    system "make"

    ENV.deparallelize # Installs must be serialized
    system "make", "install", "PYTHONAPPSDIR=#{prefix}"
    system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{share}/python3"
    system "make", "quicktest" if build.include? "quicktest"

    Dir.glob("#{prefix}/*.app") { |app| mv app, app.sub(".app", " 3.app") }

    ["Headers", "Python", "Resources"].each { |f| rm(prefix/"Frameworks/Python.framework/#{f}") }
    rm prefix/"Frameworks/Python.framework/Versions/Current"

    (lib/"pkgconfig").install_symlink Dir["#{frameworks}/Python.framework/Versions/#{xy}/lib/pkgconfig/*"]

    rm bin/"2to3"

    site_packages_cellar.rmtree

    inreplace frameworks/"Python.framework/Versions/#{xy}/lib/python#{xy}/config-#{xy}m/Makefile" do |s|
      s.change_make_var! "LINKFORSHARED",
                         "-u _PyMac_Error #{opt_prefix}/Frameworks/Python.framework/Versions/#{xy}/Python"
    end

    %w[setuptools pip wheel].each do |r|
      (libexec/r).install resource(r)
    end
  end

  def post_install

    site_packages.mkpath

    site_packages_cellar.unlink if site_packages_cellar.exist?
    site_packages_cellar.parent.install_symlink site_packages

    rm_rf Dir["#{site_packages}/sitecustomize.py[co]"]
    (site_packages/"sitecustomize.py").atomic_write(sitecustomize)

    rm_rf Dir["#{site_packages}/setuptools*"]
    rm_rf Dir["#{site_packages}/distribute*"]
    rm_rf Dir["#{site_packages}/pip[-_.][0-9]*", "#{site_packages}/pip"]

    %w[setuptools pip wheel].each do |pkg|
      (libexec/pkg).cd do
        system bin/"python3", "-s", "setup.py", "--no-user-cfg", "install",
               "--force", "--verbose", "--install-scripts=#{bin}",
               "--install-lib=#{site_packages}",
               "--single-version-externally-managed",
               "--record=installed.txt"
      end
    end

    rm_rf [bin/"pip", bin/"easy_install"]
    mv bin/"wheel", bin/"wheel3"

    %W[pip3 pip#{xy} easy_install-#{xy} wheel3].each do |e|
      (HOMEBREW_PREFIX/"bin").install_symlink bin/e
    end

    include_dirs = [HOMEBREW_PREFIX/"include", Formula["openssl"].opt_include]
    library_dirs = [HOMEBREW_PREFIX/"lib", Formula["openssl"].opt_lib]

    if build.with? "sqlite"
      include_dirs << Formula["sqlite"].opt_include
      library_dirs << Formula["sqlite"].opt_lib
    end

    if build.with? "tcl-tk"
      include_dirs << Formula["homebrew/dupes/tcl-tk"].opt_include
      library_dirs << Formula["homebrew/dupes/tcl-tk"].opt_lib
    end

    cfg = lib_cellar/"distutils/distutils.cfg"
    cfg.atomic_write <<-EOF.undent
      [install]
      prefix=#{HOMEBREW_PREFIX}

      [build_ext]
      include_dirs=#{include_dirs.join ":"}
      library_dirs=#{library_dirs.join ":"}
    EOF
  end

  def xy
    version.to_s.slice(/(3.\d)/) || "3.6"
  end

  def sitecustomize
    <<-EOF.undent
      import re
      import os
      import sys

      if sys.version_info[0] != 3:
          exit('Your PYTHONPATH points to a site-packages dir for Python 3.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
               '     You should `unset PYTHONPATH` to fix this.')

      if os.path.realpath(sys.executable).startswith('#{rack}'):
          library_site = '/Library/Python/#{xy}/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site)]
          sys.path.extend(library_packages)

          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/#{xy}/lib/python#{xy}/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]

          sys.executable = '#{opt_bin}/python#{xy}'
    EOF
  end

  def caveats
    text = <<-EOS.undent
      Pip and setuptools have been installed. To update them
        pip3 install --upgrade pip setuptools

      You can install Python packages with
        pip3 install <package>

      They will install into the site-package directory

      See: https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Homebrew-and-Python.md
    EOS

    tk_caveats = <<-EOS.undent

      Apple's Tcl/Tk is not recommended for use with Python on Mac OS X 10.6.
      For more information see: http://www.python.org/download/mac/tcltk/
    EOS

    text += tk_caveats unless MacOS.version >= :lion
    text
  end

  test do
    system "#{bin}/python#{xy}", "-c", "import sqlite3"
    system "#{bin}/python#{xy}", "-c", "import tkinter; root = tkinter.Tk()"
    system bin/"pip3", "list"
  end
end

__END__
diff --git a/setup.py b/setup.py
index 2779658..902d0eb 100644
--- a/setup.py
+++ b/setup.py
@@ -1699,9 +1699,6 @@ class PyBuildExt(build_ext):
-        if (host_platform == 'darwin' and
-            self.detect_tkinter_darwin(inc_dirs, lib_dirs)):
-            return

@@ -1747,22 +1744,6 @@ class PyBuildExt(build_ext):
             if dir not in include_dirs:
                 include_dirs.append(dir)

-        # Check for various platform-specific directories
-        if host_platform == 'sunos5':
-            include_dirs.append('/usr/openwin/include')
-            added_lib_dirs.append('/usr/openwin/lib')
-        elif os.path.exists('/usr/X11R6/include'):
-            include_dirs.append('/usr/X11R6/include')
-            added_lib_dirs.append('/usr/X11R6/lib64')
-            added_lib_dirs.append('/usr/X11R6/lib')
-        elif os.path.exists('/usr/X11R5/include'):
-            include_dirs.append('/usr/X11R5/include')
-            added_lib_dirs.append('/usr/X11R5/lib')
-        else:
-            # Assume default location for X11
-            include_dirs.append('/usr/X11/include')
-            added_lib_dirs.append('/usr/X11/lib')
-
         if host_platform == 'cygwin':
             x11_inc = find_file('X11/Xlib.h', [], include_dirs)
@@ -1786,10 +1767,6 @@ class PyBuildExt(build_ext):
         if host_platform in ['aix3', 'aix4']:
             libs.append('ld')

-        # Finally, link with the X11 libraries (not appropriate on cygwin)
-        if host_platform != "cygwin":
-            libs.append('X11')
-
         ext = Extension('_tkinter', ['_tkinter.c', 'tkappinit.c'],
                         define_macros=[('WITH_APPINIT', 1)] + defs,
                         include_dirs = include_dirs,
