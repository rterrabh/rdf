module Sass
  module Plugin
    module Configuration
      def default_options
        @default_options ||= {
          :css_location       => './public/stylesheets',
          :always_update      => false,
          :always_check       => true,
          :full_exception     => true,
          :cache_location     => ".sass-cache"
        }.freeze
      end

      def reset!
        @options = nil
        clear_callbacks!
      end

      def options
        @options ||= default_options.dup
      end

      def add_template_location(template_location, css_location = options[:css_location])
        normalize_template_location!
        template_location_array << [template_location, css_location]
      end

      def remove_template_location(template_location, css_location = options[:css_location])
        normalize_template_location!
        template_location_array.delete([template_location, css_location])
      end

      def template_location_array
        old_template_location = options[:template_location]
        normalize_template_location!
        options[:template_location]
      ensure
        options[:template_location] = old_template_location
      end

      private

      def normalize_template_location!
        return if options[:template_location].is_a?(Array)
        options[:template_location] =
          case options[:template_location]
          when nil
            if options[:css_location]
              [[File.join(options[:css_location], 'sass'), options[:css_location]]]
            else
              []
            end
          when String
            [[options[:template_location], options[:css_location]]]
          else
            options[:template_location].to_a
          end
      end
    end
  end
end
