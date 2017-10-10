
require 'i18n/backend/pluralization'
#nodyna <send-481> <SD TRIVIAL (public methods)>
I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)

require 'i18n/backend/fallbacks'
#nodyna <send-482> <SD TRIVIAL (public methods)>
I18n.backend.class.send(:include, I18n::Backend::Fallbacks)

class FallbackLocaleList < Hash
  def [](locale)
    [locale, SiteSetting.default_locale.to_sym, :en].uniq.compact
  end

  def ensure_loaded!
    self[I18n.locale].each { |l| I18n.ensure_loaded! l }
  end
end

class NoFallbackLocaleList < FallbackLocaleList
  def [](locale)
    [locale]
  end
end

if Rails.env.production?
  I18n.fallbacks = FallbackLocaleList.new
else
  I18n.fallbacks = NoFallbackLocaleList.new
end
