
module I18n
  module Backend

    class Simple
      def available_locales
        LocaleSiteSetting.supported_locales.map(&:to_sym)
      end
    end

    module Base
      def load_translations(*filenames)
        unless filenames.empty?
          filenames.flatten.each { |filename| load_file(filename) }
        end
      end

    end
  end
  class << self
    alias_method :translate_no_cache, :translate
    alias_method :reload_no_cache!, :reload!
    LRU_CACHE_SIZE = 300

    def reload!
      @loaded_locales = []
      @cache = nil
      reload_no_cache!
    end

    LOAD_MUTEX = Mutex.new
    def load_locale(locale)
      LOAD_MUTEX.synchronize do
        return if @loaded_locales.include?(locale)

        if @loaded_locales.empty?
          I18n.backend.load_translations(I18n.load_path.grep(/\.rb$/))
        end

        I18n.backend.load_translations(I18n.load_path.grep Regexp.new("\\.#{locale}\\.yml$"))

        @loaded_locales << locale
      end
    end

    def ensure_loaded!(locale)
      @loaded_locales ||= []
      load_locale locale unless @loaded_locales.include?(locale)
    end

    def translate(key, *args)
      load_locale(config.locale) unless @loaded_locales.include?(config.locale)
      return translate_no_cache(key, *args) if args.length > 0

      @cache ||= LruRedux::ThreadSafeCache.new(LRU_CACHE_SIZE)
      k = "#{key}#{config.locale}#{config.backend.object_id}"

      @cache.getset(k) do
        translate_no_cache(key).freeze
      end
    end

    alias_method :t, :translate
  end
end
