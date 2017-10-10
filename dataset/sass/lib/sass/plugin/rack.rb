module Sass
  module Plugin
    class Rack
      attr_accessor :dwell

      def initialize(app, dwell = 1.0)
        @app = app
        @dwell = dwell
        @check_after = Time.now.to_f
      end

      def call(env)
        if @dwell.nil? || Time.now.to_f > @check_after
          Sass::Plugin.check_for_updates
          @check_after = Time.now.to_f + @dwell if @dwell
        end
        @app.call(env)
      end
    end
  end
end

require 'sass/plugin'
