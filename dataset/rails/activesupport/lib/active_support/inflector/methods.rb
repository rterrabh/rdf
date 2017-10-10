
require 'active_support/inflections'

module ActiveSupport
  module Inflector
    extend self

    def pluralize(word, locale = :en)
      apply_inflections(word, inflections(locale).plurals)
    end

    def singularize(word, locale = :en)
      apply_inflections(word, inflections(locale).singulars)
    end

    def camelize(term, uppercase_first_letter = true)
      string = term.to_s
      if uppercase_first_letter
        string = string.sub(/^[a-z\d]*/) { inflections.acronyms[$&] || $&.capitalize }
      else
        string = string.sub(/^(?:#{inflections.acronym_regex}(?=\b|[A-Z_])|\w)/) { $&.downcase }
      end
      string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{inflections.acronyms[$2] || $2.capitalize}" }
      string.gsub!(/\//, '::')
      string
    end

    def underscore(camel_cased_word)
      return camel_cased_word unless camel_cased_word =~ /[A-Z-]|::/
      word = camel_cased_word.to_s.gsub(/::/, '/')
      word.gsub!(/(?:(?<=([A-Za-z\d]))|\b)(#{inflections.acronym_regex})(?=\b|[^a-z])/) { "#{$1 && '_'}#{$2.downcase}" }
      word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def humanize(lower_case_and_underscored_word, options = {})
      result = lower_case_and_underscored_word.to_s.dup

      inflections.humans.each { |(rule, replacement)| break if result.sub!(rule, replacement) }

      result.sub!(/\A_+/, '')
      result.sub!(/_id\z/, '')
      result.tr!('_', ' ')

      result.gsub!(/([a-z\d]*)/i) do |match|
        "#{inflections.acronyms[match] || match.downcase}"
      end

      if options.fetch(:capitalize, true)
        result.sub!(/\A\w/) { |match| match.upcase }
      end

      result
    end

    def titleize(word)
      humanize(underscore(word)).gsub(/\b(?<!['’`])[a-z]/) { $&.capitalize }
    end

    def tableize(class_name)
      pluralize(underscore(class_name))
    end

    def classify(table_name)
      camelize(singularize(table_name.to_s.sub(/.*\./, '')))
    end

    def dasherize(underscored_word)
      underscored_word.tr('_', '-')
    end

    def demodulize(path)
      path = path.to_s
      if i = path.rindex('::')
        path[(i+2)..-1]
      else
        path
      end
    end

    def deconstantize(path)
      path.to_s[0, path.rindex('::') || 0] # implementation based on the one in facets' Module#spacename
    end

    def foreign_key(class_name, separate_class_name_and_id_with_underscore = true)
      underscore(demodulize(class_name)) + (separate_class_name_and_id_with_underscore ? "_id" : "id")
    end

    def constantize(camel_cased_word)
      names = camel_cased_word.split('::')

      #nodyna <const_get-1007> <CG COMPLEX (change-prone variable)>
      Object.const_get(camel_cased_word) if names.empty?

      names.shift if names.size > 1 && names.first.empty?

      names.inject(Object) do |constant, name|
        if constant == Object
          #nodyna <const_get-1008> <CG COMPLEX (array)>
          constant.const_get(name)
        else
          #nodyna <const_get-1009> <CG COMPLEX (array)>
          candidate = constant.const_get(name)
          next candidate if constant.const_defined?(name, false)
          next candidate unless Object.const_defined?(name)

          constant = constant.ancestors.inject do |const, ancestor|
            break const    if ancestor == Object
            break ancestor if ancestor.const_defined?(name, false)
            const
          end

          #nodyna <const_get-1010> <CG COMPLEX (array)>
          constant.const_get(name, false)
        end
      end
    end

    def safe_constantize(camel_cased_word)
      constantize(camel_cased_word)
    rescue NameError => e
      raise if e.name && !(camel_cased_word.to_s.split("::").include?(e.name.to_s) ||
        e.name.to_s == camel_cased_word.to_s)
    rescue ArgumentError => e
      raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
    end

    def ordinal(number)
      abs_number = number.to_i.abs

      if (11..13).include?(abs_number % 100)
        "th"
      else
        case abs_number % 10
          when 1; "st"
          when 2; "nd"
          when 3; "rd"
          else    "th"
        end
      end
    end

    def ordinalize(number)
      "#{number}#{ordinal(number)}"
    end

    private

    def const_regexp(camel_cased_word) #:nodoc:
      parts = camel_cased_word.split("::")

      return Regexp.escape(camel_cased_word) if parts.blank?

      last  = parts.pop

      parts.reverse.inject(last) do |acc, part|
        part.empty? ? acc : "#{part}(::#{acc})?"
      end
    end

    def apply_inflections(word, rules)
      result = word.to_s.dup

      if word.empty? || inflections.uncountables.include?(result.downcase[/\b\w+\Z/])
        result
      else
        rules.each { |(rule, replacement)| break if result.sub!(rule, replacement) }
        result
      end
    end
  end
end
