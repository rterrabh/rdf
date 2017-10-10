require "hardware"
require "os/mac"
require "extend/ENV/shared"

module Stdenv
  include SharedEnvExtension

  SAFE_CFLAGS_FLAGS = "-w -pipe"
  DEFAULT_FLAGS = "-march=core2 -msse4"

  def self.extended(base)
    unless ORIGINAL_PATHS.include? HOMEBREW_PREFIX/"bin"
      base.prepend_path "PATH", "#{HOMEBREW_PREFIX}/bin"
    end
  end

  def setup_build_environment(formula = nil)
    super

    if MacOS.version >= :mountain_lion
      delete("LC_ALL")
      self["LC_CTYPE"]="C"
    end

    self["PKG_CONFIG_LIBDIR"] = determine_pkg_config_libdir

    self["ACLOCAL_PATH"] = "#{HOMEBREW_PREFIX}/share/aclocal" if MacOS.has_apple_developer_tools? && MacOS::Xcode.provides_autotools?

    self["MAKEFLAGS"] = "-j#{make_jobs}"

    unless HOMEBREW_PREFIX.to_s == "/usr/local"
      self["CPPFLAGS"] = "-isystem#{HOMEBREW_PREFIX}/include"
      self["LDFLAGS"] = "-L#{HOMEBREW_PREFIX}/lib"
      self["CMAKE_PREFIX_PATH"] = HOMEBREW_PREFIX.to_s
    end

    frameworks = HOMEBREW_PREFIX.join("Frameworks")
    if frameworks.directory?
      append "CPPFLAGS", "-F#{frameworks}"
      append "LDFLAGS", "-F#{frameworks}"
      self["CMAKE_FRAMEWORK_PATH"] = frameworks.to_s
    end

    set_cflags "-Os #{SAFE_CFLAGS_FLAGS}"

    append "LDFLAGS", "-Wl,-headerpad_max_install_names"

    #nodyna <send-673> <SD COMPLEX (change-prone variables)>
    send(compiler)

    if cc =~ GNU_GCC_REGEXP
      gcc_formula = gcc_version_formula($&)
      append_path "PATH", gcc_formula.opt_bin.to_s
    end

    macosxsdk MacOS.version

    if MacOS::Xcode.without_clt?
      append_path "PATH", "#{MacOS::Xcode.prefix}/usr/bin"
      append_path "PATH", "#{MacOS::Xcode.toolchain_path}/usr/bin"
    end
  end

  def determine_pkg_config_libdir
    paths = []
    paths << "#{HOMEBREW_PREFIX}/lib/pkgconfig"
    paths << "#{HOMEBREW_PREFIX}/share/pkgconfig"
    paths << "#{HOMEBREW_LIBRARY}/ENV/pkgconfig/#{MacOS.version}"
    paths << "/usr/lib/pkgconfig"
    paths.select { |d| File.directory? d }.join(File::PATH_SEPARATOR)
  end

  def deparallelize
    old = self["MAKEFLAGS"]
    remove "MAKEFLAGS", /-j\d+/
    if block_given?
      begin
        yield
      ensure
        self["MAKEFLAGS"] = old
      end
    end

    old
  end
  alias_method :j1, :deparallelize

  #nodyna <define_method-674> <DM MODERATE (array)>
  %w[fast O4 Og].each { |opt| define_method(opt) {} }

  %w[O3 O2 O1 O0 Os].each do |opt|
    #nodyna <define_method-675> <DM MODERATE (array)>
    define_method opt do
      remove_from_cflags(/-O./)
      append_to_cflags "-#{opt}"
    end
  end

  def determine_cc
    s = super
    MacOS.locate(s) || Pathname.new(s)
  end

  def determine_cxx
    dir, base = determine_cc.split
    dir / base.to_s.sub("gcc", "g++").sub("clang", "clang++")
  end

  def gcc_4_0
    super
    set_cpu_cflags "-march=nocona -mssse3"
  end
  alias_method :gcc_4_0_1, :gcc_4_0

  def gcc
    super
    set_cpu_cflags
  end
  alias_method :gcc_4_2, :gcc

  GNU_GCC_VERSIONS.each do |n|
    #nodyna <define_method-676> <DM MODERATE (array)>
    define_method(:"gcc-#{n}") do
      super()
      set_cpu_cflags
    end
  end

  def llvm
    super
    set_cpu_cflags
  end

  def clang
    super
    replace_in_cflags(/-Xarch_#{Hardware::CPU.arch_32_bit} (-march=\S*)/, '\1')
    map = Hardware::CPU.optimization_flags
    map = map.merge(:nehalem => "-march=native -Xclang -target-feature -Xclang -aes")
    set_cpu_cflags "-march=native", map
  end

  def remove_macosxsdk(version = MacOS.version)
    version = version.to_s
    remove_from_cflags(/ ?-mmacosx-version-min=10\.\d/)
    delete("MACOSX_DEPLOYMENT_TARGET")
    delete("CPATH")
    remove "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib"

    if (sdk = MacOS.sdk_path(version)) && !MacOS::CLT.installed?
      delete("SDKROOT")
      remove_from_cflags "-isysroot #{sdk}"
      remove "CPPFLAGS", "-isysroot #{sdk}"
      remove "LDFLAGS", "-isysroot #{sdk}"
      if HOMEBREW_PREFIX.to_s == "/usr/local"
        delete("CMAKE_PREFIX_PATH")
      else
        self["CMAKE_PREFIX_PATH"] = HOMEBREW_PREFIX.to_s
      end
      remove "CMAKE_FRAMEWORK_PATH", "#{sdk}/System/Library/Frameworks"
    end
  end

  def macosxsdk(version = MacOS.version)
    return unless OS.mac?
    remove_macosxsdk
    version = version.to_s
    append_to_cflags("-mmacosx-version-min=#{version}")
    self["MACOSX_DEPLOYMENT_TARGET"] = version
    self["CPATH"] = "#{HOMEBREW_PREFIX}/include"
    prepend "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib"

    if (sdk = MacOS.sdk_path(version)) && !MacOS::CLT.installed?
      self["SDKROOT"] = sdk
      append_path "CPATH", "#{sdk}/usr/include"
      append_to_cflags "-isysroot #{sdk}"
      append "CPPFLAGS", "-isysroot #{sdk}"
      append "LDFLAGS", "-isysroot #{sdk}"
      append_path "CMAKE_PREFIX_PATH", "#{sdk}/usr"
      append_path "CMAKE_FRAMEWORK_PATH", "#{sdk}/System/Library/Frameworks"
    end
  end

  def minimal_optimization
    set_cflags "-Os #{SAFE_CFLAGS_FLAGS}"
    macosxsdk unless MacOS::CLT.installed?
  end

  def no_optimization
    set_cflags SAFE_CFLAGS_FLAGS
    macosxsdk unless MacOS::CLT.installed?
  end

  def libxml2
    if MacOS::CLT.installed?
      append "CPPFLAGS", "-I/usr/include/libxml2"
    else
      append "CPPFLAGS", "-I#{MacOS.sdk_path}/usr/include/libxml2"
    end
  end

  def x11
    append_path "PATH", MacOS::X11.bin.to_s

    append_path "PKG_CONFIG_LIBDIR", "#{MacOS::X11.lib}/pkgconfig"
    append_path "PKG_CONFIG_LIBDIR", "#{MacOS::X11.share}/pkgconfig"

    append "LDFLAGS", "-L#{MacOS::X11.lib}"
    append_path "CMAKE_PREFIX_PATH", MacOS::X11.prefix.to_s
    append_path "CMAKE_INCLUDE_PATH", MacOS::X11.include.to_s
    append_path "CMAKE_INCLUDE_PATH", "#{MacOS::X11.include}/freetype2"

    append "CPPFLAGS", "-I#{MacOS::X11.include}"
    append "CPPFLAGS", "-I#{MacOS::X11.include}/freetype2"

    append_path "ACLOCAL_PATH", "#{MacOS::X11.share}/aclocal"

    if MacOS::XQuartz.provided_by_apple? && !MacOS::CLT.installed?
      append_path "CMAKE_PREFIX_PATH", "#{MacOS.sdk_path}/usr/X11"
    end

    append "CFLAGS", "-I#{MacOS::X11.include}" unless MacOS::CLT.installed?
  end
  alias_method :libpng, :x11

  def enable_warnings
    remove_from_cflags "-w"
  end

  def m64
    append_to_cflags "-m64"
    append "LDFLAGS", "-arch #{Hardware::CPU.arch_64_bit}"
  end

  def m32
    append_to_cflags "-m32"
    append "LDFLAGS", "-arch #{Hardware::CPU.arch_32_bit}"
  end

  def universal_binary
    append_to_cflags Hardware::CPU.universal_archs.as_arch_flags
    append "LDFLAGS", Hardware::CPU.universal_archs.as_arch_flags

    if compiler != :clang && Hardware.is_32_bit?
      replace_in_cflags(/-march=\S*/, "-Xarch_#{Hardware::CPU.arch_32_bit} \\0")
    end
  end

  def cxx11
    if compiler == :clang
      append "CXX", "-std=c++11"
      append "CXX", "-stdlib=libc++"
    elsif compiler =~ /gcc-(4\.(8|9)|5)/
      append "CXX", "-std=c++11"
    else
      raise "The selected compiler doesn't support C++11: #{compiler}"
    end
  end

  def libcxx
    if compiler == :clang
      append "CXX", "-stdlib=libc++"
    end
  end

  def libstdcxx
    if compiler == :clang
      append "CXX", "-stdlib=libstdc++"
    end
  end

  def replace_in_cflags(before, after)
    CC_FLAG_VARS.each do |key|
      self[key] = self[key].sub(before, after) if key?(key)
    end
  end

  def set_cflags(val)
    CC_FLAG_VARS.each { |key| self[key] = val }
  end

  def set_cpu_flags(flags, default = DEFAULT_FLAGS, map = Hardware::CPU.optimization_flags)
    cflags =~ /(-Xarch_#{Hardware::CPU.arch_32_bit} )-march=/
    xarch = $1.to_s
    remove flags, /(-Xarch_#{Hardware::CPU.arch_32_bit} )?-march=\S*/
    remove flags, /( -Xclang \S+)+/
    remove flags, /-mssse3/
    remove flags, /-msse4(\.\d)?/
    append flags, xarch unless xarch.empty?
    append flags, map.fetch(effective_arch, default)
  end

  def effective_arch
    if ARGV.build_bottle?
      ARGV.bottle_arch || Hardware.oldest_cpu
    elsif Hardware::CPU.intel? && !Hardware::CPU.sse4?
      Hardware.oldest_cpu
    else
      Hardware::CPU.family
    end
  end

  def set_cpu_cflags(default = DEFAULT_FLAGS, map = Hardware::CPU.optimization_flags)
    set_cpu_flags CC_FLAG_VARS, default, map
  end

  def make_jobs
    if self["HOMEBREW_MAKE_JOBS"].to_i > 0
      self["HOMEBREW_MAKE_JOBS"].to_i
    else
      Hardware::CPU.cores
    end
  end

  def refurbish_args; end
end
