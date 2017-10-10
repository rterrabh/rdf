class FrameworkPythonRequirement < Requirement
  fatal true

  satisfy do
    q = `python -c "import distutils.sysconfig as c; print(c.get_config_var('PYTHONFRAMEWORK'))"`
    !q.chomp.empty?
  end

  def message
    "Python needs to be built as a framework."
  end
end

class Macvim < Formula
  desc "GUI for vim, made for OS X"
  homepage "https://code.google.com/p/macvim/"
  url "https://github.com/macvim-dev/macvim/archive/snapshot-77.tar.gz"
  version "7.4-77"
  sha256 "6b7f4b48ecef4a00dca17efef551884fcea1aa9897005497d31f52da7304bc5f"

  head "https://github.com/macvim-dev/macvim.git"

  option "with-custom-icons", "Try to generate custom document icons"
  option "with-override-system-vim", "Override system vim"

  deprecated_option "custom-icons" => "with-custom-icons"
  deprecated_option "override-system-vim" => "with-override-system-vim"

  depends_on :xcode => :build
  depends_on "cscope" => :recommended
  depends_on "lua" => :optional
  depends_on "luajit" => :optional
  depends_on :python => :recommended
  depends_on :python3 => :optional
  depends_on FrameworkPythonRequirement if build.with? "python"

  env :std if MacOS.version <= :snow_leopard

  def install
    ENV.delete("PYTHONPATH")

    ENV["ARCHFLAGS"] = "-arch #{MacOS.preferred_arch}"

    ENV.clang if MacOS.version >= :lion

    args = %W[
      --with-features=huge
      --enable-multibyte
      --with-macarchs=#{MacOS.preferred_arch}
      --enable-perlinterp
      --enable-rubyinterp
      --enable-tclinterp
      --with-tlib=ncurses
      --with-compiledby=Homebrew
      --with-local-dir=#{HOMEBREW_PREFIX}
    ]

    args << "--enable-cscope" if build.with? "cscope"

    if build.with? "lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
    end

    if build.with? "luajit"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{HOMEBREW_PREFIX}"
      args << "--with-luajit"
    end

    if build.with? "python3"
      args << "--enable-python3interp"
    elsif build.with? "python"
      ENV.prepend "LDFLAGS", `python-config --ldflags`.chomp
      ENV.prepend "CFLAGS", `python-config --cflags`.chomp
      framework_script = <<-EOS.undent
        import distutils.sysconfig
        print distutils.sysconfig.get_config_var("PYTHONFRAMEWORKPREFIX")
      EOS
      framework_prefix = `python -c '#{framework_script}'`.strip
      unless framework_prefix == "/System/Library/Frameworks"
        ENV.prepend "LDFLAGS", "-F#{framework_prefix}"
        ENV.prepend "CFLAGS", "-F#{framework_prefix}"
      end
      args << "--enable-pythoninterp"
    end

    unless MacOS::CLT.installed?
      args << "--with-developer-dir=#{MacOS::Xcode.prefix}/Platforms/MacOSX.platform/Developer"
      args << "--with-macsdk=#{MacOS.version}"
    end

    system "./configure", *args

    if build.with? "custom-icons"
      system "make", "-C", "src/MacVim/icons", "getenvy"
    else
      inreplace "src/MacVim/icons/Makefile", "$(MAKE) -C makeicns", ""
      inreplace "src/MacVim/icons/make_icons.py", "dont_create = False", "dont_create = True"
    end

    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    inreplace "src/MacVim/mvim", %r{^# VIM_APP_DIR=\/Applications$},
                                 "VIM_APP_DIR=#{prefix}"
    bin.install "src/MacVim/mvim"

    executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    executables += %w[vi vim vimdiff view vimex] if build.with? "override-system-vim"
    executables.each { |e| bin.install_symlink "mvim" => e }
  end

  def caveats
    if build.with?("python") && build.with?("python3")
      <<-EOS.undent
        MacVim can no longer be brewed with dynamic support for both Python versions.
        Only Python 3 support has been provided.
      EOS
    end
  end

  test do
    if build.with? "python"
      vim_path = prefix/"MacVim.app/Contents/MacOS/Vim"

      otool_output = `otool -L #{vim_path} | grep -m 1 Python`.gsub(/\(.*\)/, "").strip.chomp

      vim_framework_path = Pathname.new(otool_output).realpath.dirname.to_s.chomp
      system_framework_path = `python-config --exec-prefix`.chomp

      assert_equal system_framework_path, vim_framework_path
    end
  end
end
