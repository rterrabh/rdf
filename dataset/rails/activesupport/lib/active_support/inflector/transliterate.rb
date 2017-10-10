require 'active_support/core_ext/string/multibyte'
require 'active_support/i18n'

module ActiveSupport
  module Inflector

    def transliterate(string, replacement = "?")
      I18n.transliterate(ActiveSupport::Multibyte::Unicode.normalize(
        ActiveSupport::Multibyte::Unicode.tidy_bytes(string), :c),
          :replacement => replacement)
    end

    def parameterize(string, sep = '-')
      parameterized_string = transliterate(string)
      parameterized_string.gsub!(/[^a-z0-9\-_]+/i, sep)
      unless sep.nil? || sep.empty?
        re_sep = Regexp.escape(sep)
        parameterized_string.gsub!(/#{re_sep}{2,}/, sep)
        parameterized_string.gsub!(/^#{re_sep}|#{re_sep}$/i, '')
      end
      parameterized_string.downcase
    end

  end
end
