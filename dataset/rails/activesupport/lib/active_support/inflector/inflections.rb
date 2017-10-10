require 'thread_safe'
require 'active_support/core_ext/array/prepend_and_append'
require 'active_support/i18n'

module ActiveSupport
  module Inflector
    extend self

    class Inflections
      @__instance__ = ThreadSafe::Cache.new

      def self.instance(locale = :en)
        @__instance__[locale] ||= new
      end

      attr_reader :plurals, :singulars, :uncountables, :humans, :acronyms, :acronym_regex

      def initialize
        @plurals, @singulars, @uncountables, @humans, @acronyms, @acronym_regex = [], [], [], [], {}, /(?=a)b/
      end

      def initialize_dup(orig) # :nodoc:
        %w(plurals singulars uncountables humans acronyms acronym_regex).each do |scope|
          #nodyna <send-1011> <SD MODERATE (array)>
          #nodyna <instance_variable_set-1012> <not yet classified>
          instance_variable_set("@#{scope}", orig.send(scope).dup)
        end
      end

      def acronym(word)
        @acronyms[word.downcase] = word
        @acronym_regex = /#{@acronyms.values.join("|")}/
      end

      def plural(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @plurals.prepend([rule, replacement])
      end

      def singular(rule, replacement)
        @uncountables.delete(rule) if rule.is_a?(String)
        @uncountables.delete(replacement)
        @singulars.prepend([rule, replacement])
      end

      def irregular(singular, plural)
        @uncountables.delete(singular)
        @uncountables.delete(plural)

        s0 = singular[0]
        srest = singular[1..-1]

        p0 = plural[0]
        prest = plural[1..-1]

        if s0.upcase == p0.upcase
          plural(/(#{s0})#{srest}$/i, '\1' + prest)
          plural(/(#{p0})#{prest}$/i, '\1' + prest)

          singular(/(#{s0})#{srest}$/i, '\1' + srest)
          singular(/(#{p0})#{prest}$/i, '\1' + srest)
        else
          plural(/#{s0.upcase}(?i)#{srest}$/,   p0.upcase   + prest)
          plural(/#{s0.downcase}(?i)#{srest}$/, p0.downcase + prest)
          plural(/#{p0.upcase}(?i)#{prest}$/,   p0.upcase   + prest)
          plural(/#{p0.downcase}(?i)#{prest}$/, p0.downcase + prest)

          singular(/#{s0.upcase}(?i)#{srest}$/,   s0.upcase   + srest)
          singular(/#{s0.downcase}(?i)#{srest}$/, s0.downcase + srest)
          singular(/#{p0.upcase}(?i)#{prest}$/,   s0.upcase   + srest)
          singular(/#{p0.downcase}(?i)#{prest}$/, s0.downcase + srest)
        end
      end

      def uncountable(*words)
        @uncountables += words.flatten.map(&:downcase)
      end

      def human(rule, replacement)
        @humans.prepend([rule, replacement])
      end

      def clear(scope = :all)
        case scope
          when :all
            @plurals, @singulars, @uncountables, @humans = [], [], [], []
          else
            #nodyna <instance_variable_set-1013> <not yet classified>
            instance_variable_set "@#{scope}", []
        end
      end
    end

    def inflections(locale = :en)
      if block_given?
        yield Inflections.instance(locale)
      else
        Inflections.instance(locale)
      end
    end
  end
end
