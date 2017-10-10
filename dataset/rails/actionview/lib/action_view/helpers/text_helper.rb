require 'active_support/core_ext/string/filters'
require 'active_support/core_ext/array/extract_options'

module ActionView
  module Helpers #:nodoc:
    module TextHelper
      extend ActiveSupport::Concern

      include SanitizeHelper
      include TagHelper
      include OutputSafetyHelper

      def concat(string)
        output_buffer << string
      end

      def safe_concat(string)
        output_buffer.respond_to?(:safe_concat) ? output_buffer.safe_concat(string) : concat(string)
      end

      def truncate(text, options = {}, &block)
        if text
          length  = options.fetch(:length, 30)

          content = text.truncate(length, options)
          content = options[:escape] == false ? content.html_safe : ERB::Util.html_escape(content)
          content << capture(&block) if block_given? && text.length > length
          content
        end
      end

      def highlight(text, phrases, options = {})
        text = sanitize(text) if options.fetch(:sanitize, true)

        if text.blank? || phrases.blank?
          text || ""
        else
          match = Array(phrases).map do |p|
            Regexp === p ? p.to_s : Regexp.escape(p)
          end.join('|')

          if block_given?
            text.gsub(/(#{match})(?![^<]*?>)/i) { |found| yield found }
          else
            highlighter = options.fetch(:highlighter, '<mark>\1</mark>')
            text.gsub(/(#{match})(?![^<]*?>)/i, highlighter)
          end
        end.html_safe
      end

      def excerpt(text, phrase, options = {})
        return unless text && phrase

        separator = options.fetch(:separator, nil) || ""
        case phrase
        when Regexp
          regex = phrase
        else
          regex = /#{Regexp.escape(phrase)}/i
        end

        return unless matches = text.match(regex)
        phrase = matches[0]

        unless separator.empty?
          text.split(separator).each do |value|
            if value.match(regex)
              regex = phrase = value
              break
            end
          end
        end

        first_part, second_part = text.split(phrase, 2)

        prefix, first_part   = cut_excerpt_part(:first, first_part, separator, options)
        postfix, second_part = cut_excerpt_part(:second, second_part, separator, options)

        affix = [first_part, separator, phrase, separator, second_part].join.strip
        [prefix, affix, postfix].join
      end

      def pluralize(count, singular, plural = nil)
        word = if (count == 1 || count =~ /^1(\.0+)?$/)
          singular
        else
          plural || singular.pluralize
        end

        "#{count || 0} #{word}"
      end

      def word_wrap(text, options = {})
        line_width = options.fetch(:line_width, 80)

        text.split("\n").collect! do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end

      def simple_format(text, html_options = {}, options = {})
        wrapper_tag = options.fetch(:wrapper_tag, :p)

        text = sanitize(text) if options.fetch(:sanitize, true)
        paragraphs = split_paragraphs(text)

        if paragraphs.empty?
          content_tag(wrapper_tag, nil, html_options)
        else
          paragraphs.map! { |paragraph|
            content_tag(wrapper_tag, raw(paragraph), html_options)
          }.join("\n\n").html_safe
        end
      end

      def cycle(first_value, *values)
        options = values.extract_options!
        name = options.fetch(:name, 'default')

        values.unshift(*first_value)

        cycle = get_cycle(name)
        unless cycle && cycle.values == values
          cycle = set_cycle(name, Cycle.new(*values))
        end
        cycle.to_s
      end

      def current_cycle(name = "default")
        cycle = get_cycle(name)
        cycle.current_value if cycle
      end

      def reset_cycle(name = "default")
        cycle = get_cycle(name)
        cycle.reset if cycle
      end

      class Cycle #:nodoc:
        attr_reader :values

        def initialize(first_value, *values)
          @values = values.unshift(first_value)
          reset
        end

        def reset
          @index = 0
        end

        def current_value
          @values[previous_index].to_s
        end

        def to_s
          value = @values[@index].to_s
          @index = next_index
          return value
        end

        private

        def next_index
          step_index(1)
        end

        def previous_index
          step_index(-1)
        end

        def step_index(n)
          (@index + n) % @values.size
        end
      end

      private
        def get_cycle(name)
          @_cycles = Hash.new unless defined?(@_cycles)
          return @_cycles[name]
        end

        def set_cycle(name, cycle_object)
          @_cycles = Hash.new unless defined?(@_cycles)
          @_cycles[name] = cycle_object
        end

        def split_paragraphs(text)
          return [] if text.blank?

          text.to_str.gsub(/\r\n?/, "\n").split(/\n\n+/).map! do |t|
            t.gsub!(/([^\n]\n)(?=[^\n])/, '\1<br />') || t
          end
        end

        def cut_excerpt_part(part_position, part, separator, options)
          return "", "" unless part

          radius   = options.fetch(:radius, 100)
          omission = options.fetch(:omission, "...")

          part = part.split(separator)
          part.delete("")
          affix = part.size > radius ? omission : ""

          part = if part_position == :first
            drop_index = [part.length - radius, 0].max
            part.drop(drop_index)
          else
            part.first(radius)
          end

          return affix, part.join(separator)
        end
    end
  end
end
