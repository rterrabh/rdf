require 'fileutils'

require 'sass'
require 'sass/plugin/compiler'

module Sass
  module Plugin
    extend self

    @checked_for_updates = false

    attr_accessor :checked_for_updates

    def check_for_updates
      return unless !Sass::Plugin.checked_for_updates ||
          Sass::Plugin.options[:always_update] || Sass::Plugin.options[:always_check]
      update_stylesheets
    end

    def compiler
      @compiler ||= Compiler.new
    end

    def update_stylesheets(individual_files = [])
      return if options[:never_update]
      compiler.update_stylesheets(individual_files)
    end

    def force_update_stylesheets(individual_files = [])
      Compiler.new(options.dup.merge(
          :never_update => false,
          :always_update => true,
          :cache => false)).update_stylesheets(individual_files)
    end

    def method_missing(method, *args, &block)
      if compiler.respond_to?(method)
        #nodyna <send-2985> <SD COMPLEX (change-prone variables)>
        compiler.send(method, *args, &block)
      else
        super
      end
    end

    def respond_to?(method)
      super || compiler.respond_to?(method)
    end

    def options
      compiler.options
    end
  end
end

if defined?(ActionController)
  require 'sass/plugin/rails' unless Sass::Util.ap_geq_3?
elsif defined?(Merb::Plugins)
  require 'sass/plugin/merb'
else
  require 'sass/plugin/generic'
end
