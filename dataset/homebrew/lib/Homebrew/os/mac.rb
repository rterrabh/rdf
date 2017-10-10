require "hardware"
require "os/mac/version"
require "os/mac/xcode"
require "os/mac/xquartz"

module OS
  module Mac
    extend self

    ::MacOS = self # compatibility

    def version
      @version ||= Version.new(MACOS_VERSION)
    end

    def cat
      version.to_sym
    end

    def locate(tool)
      (@locate ||= {}).fetch(tool) do |key|
        @locate[key] = if File.executable?(path = "/usr/bin/#{tool}")
          Pathname.new path
        elsif (path = HOMEBREW_PREFIX/"bin/#{tool}").executable?
          path
        else
          path = Utils.popen_read("/usr/bin/xcrun", "-no-cache", "-find", tool).chomp
          Pathname.new(path) if File.executable?(path)
        end
      end
    end

    def install_name_tool
      if (path = HOMEBREW_PREFIX/"opt/cctools/bin/install_name_tool").executable?
        path
      else
        locate("install_name_tool")
      end
    end

    def otool
      if (path = HOMEBREW_PREFIX/"opt/cctools/bin/otool").executable?
        path
      else
        locate("otool")
      end
    end

    def has_apple_developer_tools?
      Xcode.installed? || CLT.installed?
    end

    def active_developer_dir
      @active_developer_dir ||= Utils.popen_read("/usr/bin/xcode-select", "-print-path").strip
    end

    def sdk_path(v = version)
      (@sdk_path ||= {}).fetch(v.to_s) do |key|
        opts = []
        opts << Utils.popen_read(locate("xcodebuild"), "-version", "-sdk", "macosx#{v}", "Path").chomp
        opts << "#{Xcode.prefix}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX#{v}.sdk"
        opts << "/Developer/SDKs/MacOSX#{v}.sdk"
        @sdk_path[key] = opts.map { |a| Pathname.new(a) }.detect(&:directory?)
      end
    end

    def default_cc
      cc = locate "cc"
      cc.realpath.basename.to_s rescue nil
    end

    def default_compiler
      case default_cc
      when /^gcc-4.0/ then :gcc_4_0
      when /^gcc/ then :gcc
      when /^llvm/ then :llvm
      when "clang" then :clang
      else
        if Xcode.version >= "4.3"
          :clang
        elsif Xcode.version >= "4.2"
          :llvm
        else
          :gcc
        end
      end
    end

    def gcc_40_build_version
      @gcc_40_build_version ||=
        if (path = locate("gcc-4.0"))
        `#{path} --version`[/build (\d{4,})/, 1].to_i
        end
    end
    alias_method :gcc_4_0_build_version, :gcc_40_build_version

    def gcc_42_build_version
      @gcc_42_build_version ||=
        begin
          gcc = MacOS.locate("gcc-4.2") || HOMEBREW_PREFIX.join("opt/apple-gcc42/bin/gcc-4.2")
          if gcc.exist? && gcc.realpath.basename.to_s !~ /^llvm/
            `#{gcc} --version`[/build (\d{4,})/, 1].to_i
          end
        end
    end
    alias_method :gcc_build_version, :gcc_42_build_version

    def llvm_build_version
      @llvm_build_version ||=
        if (path = locate("llvm-gcc")) && path.realpath.basename.to_s !~ /^clang/
        `#{path} --version`[/LLVM build (\d{4,})/, 1].to_i
        end
    end

    def clang_version
      @clang_version ||=
        if (path = locate("clang"))
        `#{path} --version`[/(?:clang|LLVM) version (\d\.\d)/, 1]
        end
    end

    def clang_build_version
      @clang_build_version ||=
        if (path = locate("clang"))
        `#{path} --version`[/clang-(\d{2,})/, 1].to_i
        end
    end

    def non_apple_gcc_version(cc)
      (@non_apple_gcc_version ||= {}).fetch(cc) do
        path = HOMEBREW_PREFIX.join("opt", "gcc", "bin", cc)
        path = locate(cc) unless path.exist?
        version = `#{path} --version`[/gcc(?:-\d(?:\.\d)? \(.+\))? (\d\.\d\.\d)/, 1] if path
        @non_apple_gcc_version[cc] = version
      end
    end

    def clear_version_cache
      @gcc_40_build_version = @gcc_42_build_version = @llvm_build_version = nil
      @clang_version = @clang_build_version = nil
      @non_apple_gcc_version = {}
    end

    def macports_or_fink
      paths = []

      %w[port fink].each do |ponk|
        path = which(ponk)
        paths << path unless path.nil?
      end

      %w[/sw/bin/fink /opt/local/bin/port].each do |ponk|
        path = Pathname.new(ponk)
        paths << path if path.exist?
      end

      %w[/sw /opt/local].map { |p| Pathname.new(p) }.each do |path|
        paths << path if path.exist? && !path.readable?
      end

      paths.uniq
    end

    def prefer_64_bit?
      Hardware::CPU.is_64_bit? && version > :leopard
    end

    def preferred_arch
      if prefer_64_bit?
        Hardware::CPU.arch_64_bit
      else
        Hardware::CPU.arch_32_bit
      end
    end

    STANDARD_COMPILERS = {
      "2.5"   => { :gcc_40_build => 5370 },
      "3.1.4" => { :gcc_40_build => 5493, :gcc_42_build => 5577 },
      "3.2.6" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "1.7", :clang_build => 77 },
      "4.0"   => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.0.1" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.0.2" => { :gcc_40_build => 5494, :gcc_42_build => 5666, :llvm_build => 2335, :clang => "2.0", :clang_build => 137 },
      "4.2"   => { :llvm_build => 2336, :clang => "3.0", :clang_build => 211 },
      "4.3"   => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.1" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.2" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.3.3" => { :llvm_build => 2336, :clang => "3.1", :clang_build => 318 },
      "4.4"   => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
      "4.4.1" => { :llvm_build => 2336, :clang => "4.0", :clang_build => 421 },
      "4.5"   => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.5.1" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.5.2" => { :llvm_build => 2336, :clang => "4.1", :clang_build => 421 },
      "4.6"   => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.1" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.2" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "4.6.3" => { :llvm_build => 2336, :clang => "4.2", :clang_build => 425 },
      "5.0"   => { :clang => "5.0", :clang_build => 500 },
      "5.0.1" => { :clang => "5.0", :clang_build => 500 },
      "5.0.2" => { :clang => "5.0", :clang_build => 500 },
      "5.1"   => { :clang => "5.1", :clang_build => 503 },
      "5.1.1" => { :clang => "5.1", :clang_build => 503 },
      "6.0"   => { :clang => "6.0", :clang_build => 600 },
      "6.0.1" => { :clang => "6.0", :clang_build => 600 },
      "6.1"   => { :clang => "6.0", :clang_build => 600 },
      "6.1.1" => { :clang => "6.0", :clang_build => 600 },
      "6.2"   => { :clang => "6.0", :clang_build => 600 },
      "6.3"   => { :clang => "6.1", :clang_build => 602 },
      "6.3.1" => { :clang => "6.1", :clang_build => 602 },
      "6.3.2" => { :clang => "6.1", :clang_build => 602 },
      "6.4"   => { :clang => "6.1", :clang_build => 602 },
      "7.0"   => { :clang => "7.0", :clang_build => 700 }
    }

    def compilers_standard?
      STANDARD_COMPILERS.fetch(Xcode.version.to_s).all? do |method, build|
        #nodyna <send-623> <SD MODERATE (array)>
        send(:"#{method}_version") == build
      end
    rescue IndexError
      onoe <<-EOS.undent
        Homebrew doesn't know what compiler versions ship with your version
        of Xcode (#{Xcode.version}). Please `brew update` and if that doesn't help, file
        an issue with the output of `brew --config`:
          https://github.com/Homebrew/homebrew/issues

        Note that we only track stable, released versions of Xcode.

        Thanks!
      EOS
    end

    def app_with_bundle_id(*ids)
      path = mdfind(*ids).first
      Pathname.new(path) unless path.nil? || path.empty?
    end

    def mdfind(*ids)
      return [] unless OS.mac?
      (@mdfind ||= {}).fetch(ids) do
        @mdfind[ids] = Utils.popen_read("/usr/bin/mdfind", mdfind_query(*ids)).split("\n")
      end
    end

    def pkgutil_info(id)
      (@pkginfo ||= {}).fetch(id) do |key|
        @pkginfo[key] = Utils.popen_read("/usr/sbin/pkgutil", "--pkg-info", key).strip
      end
    end

    def mdfind_query(*ids)
      ids.map! { |id| "kMDItemCFBundleIdentifier == #{id}" }.join(" || ")
    end
  end
end
