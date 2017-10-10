module Spree
  module TestingSupport
    module Preferences
      def reset_spree_preferences(&config_block)
        Spree::Preferences::Store.instance.persistence = false
        Spree::Preferences::Store.instance.clear_cache

        config = Rails.application.config.spree.preferences
        configure_spree_preferences &config_block if block_given?
      end

      def configure_spree_preferences
        config = Rails.application.config.spree.preferences
        yield(config) if block_given?
      end

      def assert_preference_unset(preference)
        find("#preferences_#{preference}")['checked'].should be false
        Spree::Config[preference].should be false
      end
    end
  end
end

