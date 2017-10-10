require 'rbconfig'
require 'shellwords'
require 'tmpdir'

require "vagrant/util/subprocess"

module Vagrant
  module Util
    class Platform
      class << self
        def cygwin?
          return true if ENV["VAGRANT_DETECTED_OS"] &&
            ENV["VAGRANT_DETECTED_OS"].downcase.include?("cygwin")

          platform.include?("cygwin")
        end

        [:darwin, :bsd, :freebsd, :linux, :solaris].each do |type|
          #nodyna <define_method-3079> <DM MODERATE (array)>
          define_method("#{type}?") do
            platform.include?(type.to_s)
          end
        end

        def windows?
          %W[mingw mswin].each do |text|
            return true if platform.include?(text)
          end

          false
        end

        def windows_admin?
          require 'win32/registry'

          begin
            Win32::Registry::HKEY_USERS.open("S-1-5-19") {}
            return true
          rescue Win32::Registry::Error
            return false
          end
        end

        def cygwin_path(path)
          if cygwin?
            begin
              process = Subprocess.execute("cygpath", "-u", "-a", path.to_s)
              return process.stdout.chomp
            rescue Errors::CommandUnavailableWindows
            end
          end

          process = Subprocess.execute(
            "bash",
            "--noprofile",
            "--norc",
            "-c", "cd #{Shellwords.escape(path)} && pwd")
          return process.stdout.chomp
        end

        def cygwin_windows_path(path)
          return path if !cygwin?

          path = path.gsub("\\", "/")

          process = Subprocess.execute("cygpath", "-w", "-l", "-a", path.to_s)
          return process.stdout.chomp
        end

        def fs_case_sensitive?
          Dir.mktmpdir("vagrant") do |tmp_dir|
            tmp_file = File.join(tmp_dir, "FILE")
            File.open(tmp_file, "w") do |f|
              f.write("foo")
            end

            !File.file?(File.join(tmp_dir, "file"))
          end
        end

        def fs_real_path(path, **opts)
          path = Pathname.new(File.expand_path(path))

          if path.exist? && !fs_case_sensitive?
            original = []
            while !path.root?
              original.unshift(path.basename.to_s)
              path = path.parent
            end

            original.each do |single|
              Dir.entries(path).each do |entry|
                if entry.downcase == single.encode('filesystem').downcase
                  path = path.join(entry)
                end
              end
            end
          end

          if windows?
            path = path.to_s
            if path[1] == ":"
              path[0] = path[0].upcase
            end

            path = Pathname.new(path)
          end

          path
        end

        def windows_unc_path(path)
          "\\\\?\\" + path.gsub("/", "\\")
        end

        def terminal_supports_colors?
          if windows?
            return true if ENV.key?("ANSICON")
            return true if cygwin?
            return true if ENV["TERM"] == "cygwin"
            return false
          end

          true
        end

        def platform
          RbConfig::CONFIG["host_os"].downcase
        end
      end
    end
  end
end
