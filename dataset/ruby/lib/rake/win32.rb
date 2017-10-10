
module Rake
  require 'rake/alt_system'

  module Win32 # :nodoc: all

    class Win32HomeError < RuntimeError
    end

    class << self
      def windows?
        AltSystem::WINDOWS
      end

      def rake_system(*cmd)
        AltSystem.system(*cmd)
      end

      def win32_system_dir #:nodoc:
        win32_shared_path = ENV['HOME']
        if win32_shared_path.nil? && ENV['HOMEDRIVE'] && ENV['HOMEPATH']
          win32_shared_path = ENV['HOMEDRIVE'] + ENV['HOMEPATH']
        end

        win32_shared_path ||= ENV['APPDATA']
        win32_shared_path ||= ENV['USERPROFILE']
        raise Win32HomeError,
          "Unable to determine home path environment variable." if
            win32_shared_path.nil? or win32_shared_path.empty?
        normalize(File.join(win32_shared_path, 'Rake'))
      end

      def normalize(path)
        path.gsub(/\\/, '/')
      end

    end
  end
end
