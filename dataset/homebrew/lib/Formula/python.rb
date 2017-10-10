class Python < Formula
  desc "Interpreted, interactive, object-oriented programming language"
  homepage "https://www.python.org"
  head "https://hg.python.org/cpython", :using => :hg, :branch => "2.7"
  url "https://www.python.org/ftp/python/2.7.10/Python-2.7.10.tgz"
  sha256 "eda8ce6eec03e74991abb5384170e7c65fcd7522e409b8e83d7e6372add0f12a"
  revision 2

  bottle do
    sha256 "df7af5b6865765e96acdad1922c4983439f8b058845ac5023f8fe8ec79ea3d4e" => :yosemite
    sha256 "c0fab9719d000e1f6150423538b01059471b6eb1777257f5e71a29e1457311e4" => :mavericks
    sha256 "90e0f06ef02d3852cd805776ff172e909a2d69c97536ec0fae599d3ebd00bfec" => :mountain_lion
  end

  option :universal
  option "with-quicktest", "Run `make quicktest` after the build (for devs; may fail)"
  option "with-tcl-tk", "Use Homebrew's Tk instead of OS X Tk (has optional Cocoa and threads support)"
  option "with-poll", "Enable select.poll, which is not fully implemented on OS X (https://bugs.python.org/issue5154)"

  deprecated_option "quicktest" => "with-quicktest"
  deprecated_option "with-brewed-tk" => "with-tcl-tk"

  depends_on "pkg-config" => :build
  depends_on "readline" => :recommended
  depends_on "sqlite" => :recommended
  depends_on "gdbm" => :recommended
  depends_on "openssl"
  depends_on "homebrew/dupes/tcl-tk" => :optional
  depends_on "berkeley-db4" => :optional
  depends_on :x11 if build.with?("tcl-tk") && Tab.for_name("homebrew/dupes/tcl-tk").with?("x11")

  skip_clean "bin/pip", "bin/pip-2.7"
  skip_clean "bin/easy_install", "bin/easy_install-2.7"

  resource "setuptools" do
    url "https://pypi.python.org/packages/source/s/setuptools/setuptools-18.0.1.tar.gz"
    sha256 "4d49c99fd51edf22baa997fb6105b07482feaebcb174b7d348a4307c29264b94"
  end

  resource "pip" do
    url "https://pypi.python.org/packages/source/p/pip/pip-7.1.0.tar.gz"
    sha256 "d5275ba3221182a5dd1b6bcfbfc5ec277fb399dd23226d6fa018048f7e0f10f2"
  end

  resource "wheel" do
    url "https://pypi.python.org/packages/source/w/wheel/wheel-0.24.0.tar.gz"
    sha256 "ef832abfedea7ed86b6eae7400128f88053a1da81a37c00613b1279544d585aa"
  end

  patch do
    url "https://bugs.python.org/file30805/issue10910-workaround.txt"
    sha256 "c075353337f9ff3ccf8091693d278782fcdff62c113245d8de43c5c7acc57daf"
  end

  patch :DATA if build.with? "tcl-tk"

  def lib_cellar
    prefix/"Frameworks/Python.framework/Versions/2.7/lib/python2.7"
  end

  def site_packages_cellar
    lib_cellar/"site-packages"
  end

  def site_packages
    HOMEBREW_PREFIX/"lib/python2.7/site-packages"
  end

  def pour_bottle?
    MacOS::CLT.installed?
  end

  def install
    if build.with? "poll"
      opoo "The given option --with-poll enables a somewhat broken poll() on OS X (https://bugs.python.org/issue5154)."
    end

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
      s.gsub! "/usr/include/db4", Formula["berkeley-db4"].opt_include
    end

    if build.universal?
      ENV.universal_binary
      args << "--enable-universalsdk=/" << "--with-universal-archs=intel"
    end

    if build.with? "sqlite"
      inreplace("setup.py", 'sqlite_defines.append(("SQLITE_OMIT_LOAD_EXTENSION", "1"))', "")
    end

    inreplace "./Lib/ctypes/macholib/dyld.py" do |f|
      f.gsub! "DEFAULT_LIBRARY_FALLBACK = [", "DEFAULT_LIBRARY_FALLBACK = [ '#{HOMEBREW_PREFIX}/lib',"
      f.gsub! "DEFAULT_FRAMEWORK_FALLBACK = [", "DEFAULT_FRAMEWORK_FALLBACK = [ '#{HOMEBREW_PREFIX}/Frameworks',"
    end

    if build.with? "tcl-tk"
      tcl_tk = Formula["homebrew/dupes/tcl-tk"].opt_prefix
      ENV.append "CPPFLAGS", "-I#{tcl_tk}/include"
      ENV.append "LDFLAGS", "-L#{tcl_tk}/lib"
    end

    system "./configure", *args

    if build.without? "poll"
      inreplace "pyconfig.h", /.*?(HAVE_POLL[_A-Z]*).*/, '#undef \1'
    end

    system "make"

    ENV.deparallelize # installs must be serialized
    system "make", "install", "PYTHONAPPSDIR=#{prefix}"
    system "make", "frameworkinstallextras", "PYTHONAPPSDIR=#{share}/python"
    system "make", "quicktest" if build.include? "quicktest"

    (lib/"pkgconfig").install_symlink Dir["#{frameworks}/Python.framework/Versions/Current/lib/pkgconfig/*"]

    inreplace lib_cellar/"config/Makefile" do |s|
      s.change_make_var! "LINKFORSHARED",
        "-u _PyMac_Error $(PYTHONFRAMEWORKINSTALLDIR)/Versions/$(VERSION)/$(PYTHONFRAMEWORK)"
    end

    site_packages_cellar.rmtree

    (libexec/"setuptools").install resource("setuptools")
    (libexec/"pip").install resource("pip")
    (libexec/"wheel").install resource("wheel")
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

    setup_args = ["-s", "setup.py", "--no-user-cfg", "install", "--force",
                  "--verbose",
                  "--single-version-externally-managed",
                  "--record=installed.txt",
                  "--install-scripts=#{bin}",
                  "--install-lib=#{site_packages}"]

    (libexec/"setuptools").cd { system "#{bin}/python", *setup_args }
    (libexec/"pip").cd { system "#{bin}/python", *setup_args }
    (libexec/"wheel").cd { system "#{bin}/python", *setup_args }

    %w[pip pip2 pip2.7 easy_install easy_install-2.7 wheel].each do |e|
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

  def sitecustomize
    <<-EOF.undent
      import re
      import os
      import sys

      if sys.version_info[0] != 2:
          exit('Your PYTHONPATH points to a site-packages dir for Python 2.x but you are running Python ' +
               str(sys.version_info[0]) + '.x!\\n     PYTHONPATH is currently: "' + str(os.environ['PYTHONPATH']) + '"\\n' +
               '     You should `unset PYTHONPATH` to fix this.')

      if os.path.realpath(sys.executable).startswith('#{rack}'):
          library_site = '/Library/Python/2.7/site-packages'
          library_packages = [p for p in sys.path if p.startswith(library_site)]
          sys.path = [p for p in sys.path if not p.startswith(library_site) and
                                             not p.startswith('/System')]
          sys.path.extend(library_packages)

          long_prefix = re.compile(r'#{rack}/[0-9\._abrc]+/Frameworks/Python\.framework/Versions/2\.7/lib/python2\.7/site-packages')
          sys.path = [long_prefix.sub('#{site_packages}', p) for p in sys.path]

          try:
              from _sysconfigdata import build_time_vars
              build_time_vars['LINKFORSHARED'] = '-u _PyMac_Error #{opt_prefix}/Frameworks/Python.framework/Versions/2.7/Python'
          except:
              pass  # remember: don't print here. Better to fail silently.

          sys.executable = '#{opt_bin}/python2.7'
    EOF
  end

  def caveats; <<-EOS.undent
    Pip and setuptools have been installed. To update them
      pip install --upgrade pip setuptools

    You can install Python packages with
      pip install <package>

    They will install into the site-package directory

    See: https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Homebrew-and-Python.md
    EOS
  end

  test do
    system "#{bin}/python", "-c", "import sqlite3"
    system "#{bin}/python", "-c", "import Tkinter; root = Tkinter.Tk()"
    system bin/"pip", "list"
  end
end

__END__
diff --git a/setup.py b/setup.py
index 716f08e..66114ef 100644
--- a/setup.py
+++ b/setup.py
@@ -1810,9 +1810,6 @@ class PyBuildExt(build_ext):
-        if (host_platform == 'darwin' and
-            self.detect_tkinter_darwin(inc_dirs, lib_dirs)):
-            return

@@ -1858,21 +1855,6 @@ class PyBuildExt(build_ext):
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

         if host_platform == 'cygwin':
@@ -1897,9 +1879,6 @@ class PyBuildExt(build_ext):
         if host_platform in ['aix3', 'aix4']:
             libs.append('ld')

-        # Finally, link with the X11 libraries (not appropriate on cygwin)
-        if host_platform != "cygwin":
-            libs.append('X11')

         ext = Extension('_tkinter', ['_tkinter.c', 'tkappinit.c'],
                         define_macros=[('WITH_APPINIT', 1)] + defs,
