module Capybara
  module Node
    module Actions

      def click_link_or_button(locator, options={})
        find(:link_or_button, locator, options).click
      end
      alias_method :click_on, :click_link_or_button

      def click_link(locator, options={})
        find(:link, locator, options).click
      end

      def click_button(locator, options={})
        find(:button, locator, options).click
      end

      def fill_in(locator, options={})
        raise "Must pass a hash containing 'with'" if not options.is_a?(Hash) or not options.has_key?(:with)
        with = options.delete(:with)
        fill_options = options.delete(:fill_options)
        find(:fillable_field, locator, options).set(with, fill_options)
      end

      def choose(locator, options={})
        find(:radio_button, locator, options).set(true)
      end

      def check(locator, options={})
        find(:checkbox, locator, options).set(true)
      end

      def uncheck(locator, options={})
        find(:checkbox, locator, options).set(false)
      end

      def select(value, options={})
        if options.has_key?(:from)
          from = options.delete(:from)
          find(:select, from, options).find(:option, value, options).select_option
        else
          find(:option, value, options).select_option
        end
      end

      def unselect(value, options={})
        if options.has_key?(:from)
          from = options.delete(:from)
          find(:select, from, options).find(:option, value, options).unselect_option
        else
          find(:option, value, options).unselect_option
        end
      end

      def attach_file(locator, path, options={})
        Array(path).each do |p|
          raise Capybara::FileNotFound, "cannot attach file, #{p} does not exist" unless File.exist?(p.to_s)
        end
        find(:file_field, locator, options).set(path)
      end
    end
  end
end
