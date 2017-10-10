
require 'singleton'

module Spree::Preferences

  class StoreInstance
    attr_accessor :persistence

    def initialize
      @cache = Rails.cache
      @persistence = true
    end

    def set(key, value)
      @cache.write(key, value)
      persist(key, value)
    end
    alias_method :[]=, :set

    def exist?(key)
      @cache.exist?(key) ||
      should_persist? && Spree::Preference.where(:key => key).exists?
    end

    def get(key)
      unless (val = @cache.read(key)).nil?
        return val
      end

      if should_persist?

        if preference = Spree::Preference.find_by_key(key)
          val = preference.value
        else
          val = yield
        end

        @cache.write(key, val)

        return val
      else
        yield
      end
    end
    alias_method :fetch, :get

    def delete(key)
      @cache.delete(key)
      destroy(key)
    end

    def clear_cache
      @cache.clear
    end

    private

    def persist(cache_key, value)
      return unless should_persist?

      preference = Spree::Preference.where(:key => cache_key).first_or_initialize
      preference.value = value
      preference.save
    end

    def destroy(cache_key)
      return unless should_persist?

      preference = Spree::Preference.find_by_key(cache_key)
      preference.destroy if preference
    end

    def should_persist?
      @persistence and Spree::Preference.table_exists?
    end

  end

  class Store < StoreInstance
    include Singleton
  end

end
