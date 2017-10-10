class TextCleaner

  def self.title_options
    {
      deduplicate_exclamation_marks: SiteSetting.title_prettify,
      deduplicate_question_marks: SiteSetting.title_prettify,
      replace_all_upper_case: SiteSetting.title_prettify,
      capitalize_first_letter: SiteSetting.title_prettify,
      remove_all_periods_from_the_end: SiteSetting.title_prettify,
      remove_extraneous_space: SiteSetting.title_prettify && SiteSetting.default_locale == "en",
      fixes_interior_spaces: true,
      strip_whitespaces: true
    }
  end

  def self.clean_title(title)
    TextCleaner.clean(title, TextCleaner.title_options)
  end

  def self.clean(text, opts = {})
    text.gsub!(/!+/, '!') if opts[:deduplicate_exclamation_marks]
    text.gsub!(/\?+/, '?') if opts[:deduplicate_question_marks]
    text.tr!('A-Z', 'a-z') if opts[:replace_all_upper_case] && (text =~ /[A-Z]+/) && (text == text.upcase)
    text.sub!(/\A([a-z]*)\b/) { |first| first.capitalize } if opts[:capitalize_first_letter]
    text.sub!(/([^.])\.+(\s*)\z/, '\1\2') if opts[:remove_all_periods_from_the_end]
    text.sub!(/\s+([!?]\s*)\z/, '\1') if opts[:remove_extraneous_space]
    text.gsub!(/ +/, ' ') if opts[:fixes_interior_spaces]
    text = normalize_whitespaces(text)
    text.strip! if opts[:strip_whitespaces]

    text
  end

  @@whitespaces_regexp = Regexp.new("(\u00A0|\u1680|\u180E|[\u2000-\u200A]|\u2028|\u2029|\u202F|\u205F|\u3000)", "u").freeze

  def self.normalize_whitespaces(text)
    text.gsub(@@whitespaces_regexp, ' ')
  end

end
