
require 'rubygems'


module Gem::VersionOption


  def add_platform_option(task = command, *wrap)
    OptionParser.accept Gem::Platform do |value|
      if value == Gem::Platform::RUBY then
        value
      else
        Gem::Platform.new value
      end
    end

    add_option('--platform PLATFORM', Gem::Platform,
               "Specify the platform of gem to #{task}", *wrap) do
                 |value, options|
      unless options[:added_platform] then
        Gem.platforms = [Gem::Platform::RUBY]
        options[:added_platform] = true
      end

      Gem.platforms << value unless Gem.platforms.include? value
    end
  end


  def add_prerelease_option(*wrap)
    add_option("--[no-]prerelease",
               "Allow prerelease versions of a gem", *wrap) do |value, options|
      options[:prerelease] = value
      options[:explicit_prerelease] = true
    end
  end


  def add_version_option(task = command, *wrap)
    OptionParser.accept Gem::Requirement do |value|
      Gem::Requirement.new(*value.split(/\s*,\s*/))
    end

    add_option('-v', '--version VERSION', Gem::Requirement,
               "Specify version of gem to #{task}", *wrap) do
                 |value, options|
      options[:version] = value

      explicit_prerelease_set = !options[:explicit_prerelease].nil?
      options[:explicit_prerelease] = false unless explicit_prerelease_set

      options[:prerelease] = value.prerelease? unless
        options[:explicit_prerelease]
    end
  end

end

