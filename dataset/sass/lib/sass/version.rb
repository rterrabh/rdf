require 'date'
require 'sass/util'

module Sass
  module Version
    def version
      return @@version if defined?(@@version)

      numbers = File.read(Sass::Util.scope('VERSION')).strip.split('.').
        map {|n| n =~ /^[0-9]+$/ ? n.to_i : n}
      name = File.read(Sass::Util.scope('VERSION_NAME')).strip
      @@version = {
        :major => numbers[0],
        :minor => numbers[1],
        :teeny => numbers[2],
        :name => name
      }

      if (date = version_date)
        @@version[:date] = date
      end

      if numbers[3].is_a?(String)
        @@version[:teeny] = -1
        @@version[:prerelease] = numbers[3]
        @@version[:prerelease_number] = numbers[4]
      end

      @@version[:number] = numbers.join('.')
      @@version[:string] = @@version[:number].dup

      if (rev = revision_number)
        @@version[:rev] = rev
        unless rev[0] == ?(
          @@version[:string] << "." << rev[0...7]
        end
      end

      @@version[:string] << " (#{name})"
      @@version
    end

    private

    def revision_number
      if File.exist?(Sass::Util.scope('REVISION'))
        rev = File.read(Sass::Util.scope('REVISION')).strip
        return rev unless rev =~ /^([a-f0-9]+|\(.*\))$/ || rev == '(unknown)'
      end

      return unless File.exist?(Sass::Util.scope('.git/HEAD'))
      rev = File.read(Sass::Util.scope('.git/HEAD')).strip
      return rev unless rev =~ /^ref: (.*)$/

      ref_name = $1
      ref_file = Sass::Util.scope(".git/#{ref_name}")
      info_file = Sass::Util.scope(".git/info/refs")
      return File.read(ref_file).strip if File.exist?(ref_file)
      return unless File.exist?(info_file)
      File.open(info_file) do |f|
        f.each do |l|
          sha, ref = l.strip.split("\t", 2)
          next unless ref == ref_name
          return sha
        end
      end
      nil
    end

    def version_date
      return unless File.exist?(Sass::Util.scope('VERSION_DATE'))
      DateTime.parse(File.read(Sass::Util.scope('VERSION_DATE')).strip)
    end
  end

  extend Sass::Version

  VERSION = version[:string] unless defined?(Sass::VERSION)
end
