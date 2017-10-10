module OS
  module Mac
    module Xcode
      extend self

      V4_BUNDLE_ID = "com.apple.dt.Xcode"
      V3_BUNDLE_ID = "com.apple.Xcode"

      def latest_version
        case MacOS.version
        when "10.4"  then "2.5"
        when "10.5"  then "3.1.4"
        when "10.6"  then "3.2.6"
        when "10.7"  then "4.6.3"
        when "10.8"  then "5.1.1"
        when "10.9"  then "6.2"
        when "10.10" then "6.4"
        when "10.11" then "7.0"
        else
          if MacOS.version > "10.11"
            "7.0"
          else
            raise "OS X '#{MacOS.version}' is invalid"
          end
        end
      end

      def outdated?
        version < latest_version
      end

      def without_clt?
        installed? && version >= "4.3" && !MacOS::CLT.installed?
      end

      def prefix
        @prefix ||=
          begin
            dir = MacOS.active_developer_dir

            if dir.empty? || dir == CLT::MAVERICKS_PKG_PATH || !File.directory?(dir)
              path = bundle_path
              path.join("Contents", "Developer") if path
            else
              Pathname.new(dir)
            end
          end
      end

      def toolchain_path
        Pathname.new("#{prefix}/Toolchains/XcodeDefault.xctoolchain") if installed? && version >= "4.3"
      end

      def bundle_path
        MacOS.app_with_bundle_id(V4_BUNDLE_ID, V3_BUNDLE_ID)
      end

      def installed?
        !prefix.nil?
      end

      def version
        @version ||= uncached_version
      end

      def uncached_version

        return "0" unless OS.mac?

        return nil if !MacOS::Xcode.installed? && !MacOS::CLT.installed?

        %W[#{prefix}/usr/bin/xcodebuild #{which("xcodebuild")}].uniq.each do |path|
          if File.file? path
            Utils.popen_read(path, "-version") =~ /Xcode (\d(\.\d)*)/
            return $1 if $1
          end
        end

        case MacOS.llvm_build_version.to_i
        when 1..2063 then "3.1.0"
        when 2064..2065 then "3.1.4"
        when 2366..2325
          "3.2.0"
        when 2326
          "3.2.4"
        when 2327..2333 then "3.2.5"
        when 2335
          "4.0"
        else
          case (MacOS.clang_version.to_f * 10).to_i
          when 0       then "dunno"
          when 1..14   then "3.2.2"
          when 15      then "3.2.4"
          when 16      then "3.2.5"
          when 17..20  then "4.0"
          when 21      then "4.1"
          when 22..30  then "4.2"
          when 31      then "4.3"
          when 40      then "4.4"
          when 41      then "4.5"
          when 42      then "4.6"
          when 50      then "5.0"
          when 51      then "5.1"
          when 60      then "6.0"
          when 61      then "6.1"
          when 70      then "7.0"
          else "7.0"
          end
        end
      end

      def provides_autotools?
        version < "4.3"
      end

      def provides_gcc?
        version < "4.3"
      end

      def provides_cvs?
        version < "5.0"
      end

      def default_prefix?
        if version < "4.3"
          %r{^/Developer} === prefix
        else
          %r{^/Applications/Xcode.app} === prefix
        end
      end
    end

    module CLT
      extend self

      STANDALONE_PKG_ID = "com.apple.pkg.DeveloperToolsCLILeo"
      FROM_XCODE_PKG_ID = "com.apple.pkg.DeveloperToolsCLI"
      MAVERICKS_PKG_ID = "com.apple.pkg.CLTools_Executables"
      MAVERICKS_NEW_PKG_ID = "com.apple.pkg.CLTools_Base" # obsolete
      MAVERICKS_PKG_PATH = "/Library/Developer/CommandLineTools"

      def installed?
        !!detect_version
      end

      def latest_version
        case MacOS.version
        when "10.11" then "700.0.65"
        when "10.10" then "602.0.53"
        when "10.9"  then "600.0.57"
        when "10.8"  then "503.0.40"
        else
          "425.0.28"
        end
      end

      def outdated?
        if MacOS.version >= :mavericks
          version = `#{MAVERICKS_PKG_PATH}/usr/bin/clang --version`
        else
          version = `/usr/bin/clang --version`
        end
        version = version[/clang-(\d+\.\d+\.\d+(\.\d+)?)/, 1] || "0"
        version < latest_version
      end

      def version
        @version ||= detect_version
      end

      def detect_version
        [MAVERICKS_PKG_ID, MAVERICKS_NEW_PKG_ID, STANDALONE_PKG_ID, FROM_XCODE_PKG_ID].find do |id|
          if MacOS.version >= :mavericks
            next unless File.exist?("#{MAVERICKS_PKG_PATH}/usr/bin/clang")
          end
          version = MacOS.pkgutil_info(id)[/version: (.+)$/, 1]
          return version if version
        end
      end
    end
  end
end
