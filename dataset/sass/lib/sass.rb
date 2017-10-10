dir = File.dirname(__FILE__)
$LOAD_PATH.unshift dir unless $LOAD_PATH.include?(dir)

require 'sass/version'

module Sass
  class << self
    attr_accessor :tests_running
  end

  def self.load_paths
    @load_paths ||= if ENV['SASS_PATH']
                      ENV['SASS_PATH'].split(Sass::Util.windows? ? ';' : ':')
                    else
                      []
                    end
  end

  def self.compile(contents, options = {})
    options[:syntax] ||= :scss
    Engine.new(contents, options).to_css
  end

  def self.compile_file(filename, *args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    css_filename = args.shift
    result = Sass::Engine.for_file(filename, options).render
    if css_filename
      options[:css_filename] ||= css_filename
      open(css_filename, "w") {|css_file| css_file.write(result)}
      nil
    else
      result
    end
  end
end

require 'sass/logger'
require 'sass/util'

require 'sass/engine'
require 'sass/plugin' if defined?(Merb::Plugins)
require 'sass/railtie'
require 'sass/features'
