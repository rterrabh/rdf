require "vagrant/util/platform"

module Vagrant
  module Util
    class Which
      def self.which(cmd)
        exts = nil

        if !Platform.windows? || ENV['PATHEXT'].nil?
          exts = ['']
        elsif File.extname(cmd).length != 0
          exts = ['']
        else
          exts = ENV['PATHEXT'].split(';')
        end

        ENV['PATH'].encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = "#{path}#{File::SEPARATOR}#{cmd}#{ext}"
            return exe if File.executable? exe
          end
        end

        return nil
      end
    end
  end
end
