class Pypy3 < Formula
  desc "Implementation of Python 3 in Python"
  homepage "http://pypy.org/"
  url "https://bitbucket.org/pypy/pypy/downloads/pypy3-2.4.0-src.tar.bz2"
  sha256 "d9ba207d6eecf8a0dc4414e9f4e92db1abd143e8cc6ec4a6bdcac75b29f104f3"

  bottle do
    cellar :any
    revision 6
    sha1 "b9a9d4093dba9fbd89be33a1b28039f43098860d" => :yosemite
    sha1 "4b0a2a9633ebbf8749eb1c5980add2447d74ee11" => :mavericks
    sha1 "e9c63d780fb3df53fe657d656dd9d0ccbe454f20" => :mountain_lion
  end

  depends_on :arch => :x86_64
  depends_on "pkg-config" => :build
  depends_on "openssl"

  resource "setuptools" do
    url "https://pypi.python.org/packages/source/s/setuptools/setuptools-11.3.1.tar.gz"
    sha256 "bd25f17de4ecf00116a9f7368b614a54ca1612d7945d2eafe5d97bc08c138bc5"
  end

  resource "pip" do
    url "https://pypi.python.org/packages/source/p/pip/pip-6.0.6.tar.gz"
    sha256 "3a14091299dcdb9bab9e9004ae67ac401f2b1b14a7c98de074ca74fdddf4bfa0"
  end

  fails_with :gcc

  def install
    ENV["PYTHONPATH"] = ""
    ENV["PYPY_USESSION_DIR"] = buildpath

    Dir.chdir "pypy/goal" do
      system "python", buildpath/"rpython/bin/rpython",
             "-Ojit", "--shared", "--cc", ENV.cc, "--translation-verbose",
             "--make-jobs", ENV.make_jobs, "targetpypystandalone.py"
      system "install_name_tool", "-change", "libpypy-c.dylib", libexec/"lib/libpypy3-c.dylib", "pypy-c"
      system "install_name_tool", "-id", opt_libexec/"lib/libpypy3-c.dylib", "libpypy-c.dylib"
      (libexec/"bin").install "pypy-c" => "pypy"
      (libexec/"lib").install "libpypy-c.dylib" => "libpypy3-c.dylib"
    end

    (libexec/"lib-python").install "lib-python/3"
    libexec.install %w[include lib_pypy]

    bin.install_symlink libexec/"bin/pypy" => "pypy3"
    lib.install_symlink libexec/"lib/libpypy3-c.dylib"

    %w[setuptools pip].each do |r|
      (libexec/r).install resource(r)
    end
  end

  def post_install
    %w[_sqlite3 _curses syslog gdbm _tkinter].each do |module_name|
      quiet_system bin/"pypy3", "-c", "import #{module_name}"
    end


    prefix_site_packages.mkpath

    libexec.install_symlink prefix_site_packages

    scripts_folder.mkpath
    (distutils+"distutils.cfg").atomic_write <<-EOF.undent
      [install]
      install-scripts=#{scripts_folder}
    EOF

    %w[setuptools pip].each do |pkg|
      (libexec/pkg).cd do
        system bin/"pypy3", "-s", "setup.py", "install", "--force", "--verbose"
      end
    end

    bin.install_symlink scripts_folder/"easy_install" => "easy_install_pypy3"
    bin.install_symlink scripts_folder/"pip" => "pip_pypy3"

    %w[easy_install_pypy3 pip_pypy3].each { |e| (HOMEBREW_PREFIX/"bin").install_symlink bin/e }
  end

  def caveats; <<-EOS.undent
    A "distutils.cfg" has been written to:
    specifying the install-scripts folder as:

    If you install Python packages via "pypy3 setup.py install", easy_install_pypy3,
    or pip_pypy3, any provided scripts will go into the install-scripts folder
    above, so you may want to add it to your PATH *after* #{HOMEBREW_PREFIX}/bin
    so you don't overwrite tools from CPython.

    Setuptools and pip have been installed, so you can use easy_install_pypy3 and
    pip_pypy3.
    To update pip and setuptools between pypy3 releases, run:
        pip_pypy3 install --upgrade pip setuptools

    See: https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Homebrew-and-Python.md
    EOS
  end

  def prefix_site_packages
    HOMEBREW_PREFIX+"lib/pypy3/site-packages"
  end

  def scripts_folder
    HOMEBREW_PREFIX+"share/pypy3"
  end

  def distutils
    libexec+"lib-python/3/distutils"
  end
end
