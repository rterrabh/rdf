# order: after 02-freedom_patches.rb

# Include pluralization module
require 'i18n/backend/pluralization'
#nodyna <ID:send-225> <SD TRIVIAL (public methods)>
I18n::Backend::Simple.send(:include, I18n::Backend::Pluralization)

# Include fallbacks module
require 'i18n/backend/fallbacks'
#nodyna <ID:send-226> <SD TRIVIAL (public methods)>
I18n.backend.class.send(:include, I18n::Backend::Fallbacks)

# Configure custom fallback order
class FallbackLocaleList < Hash
  def [](locale)
    # user locale, site locale, english
    # TODO - this can be extended to be per-language for a better user experience
    # (e.g. fallback zh_TW to zh_CN / vice versa)
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
