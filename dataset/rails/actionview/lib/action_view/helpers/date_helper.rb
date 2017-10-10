require 'date'
require 'action_view/helpers/tag_helper'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/date/conversions'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/object/with_options'

module ActionView
  module Helpers
    module DateHelper
      MINUTES_IN_YEAR = 525600
      MINUTES_IN_QUARTER_YEAR = 131400
      MINUTES_IN_THREE_QUARTERS_YEAR = 394200

      def distance_of_time_in_words(from_time, to_time = 0, options = {})
        options = {
          scope: :'datetime.distance_in_words'
        }.merge!(options)

        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        from_time, to_time = to_time, from_time if from_time > to_time
        distance_in_minutes = ((to_time - from_time)/60.0).round
        distance_in_seconds = (to_time - from_time).round

        I18n.with_options :locale => options[:locale], :scope => options[:scope] do |locale|
          case distance_in_minutes
            when 0..1
              return distance_in_minutes == 0 ?
                     locale.t(:less_than_x_minutes, :count => 1) :
                     locale.t(:x_minutes, :count => distance_in_minutes) unless options[:include_seconds]

              case distance_in_seconds
                when 0..4   then locale.t :less_than_x_seconds, :count => 5
                when 5..9   then locale.t :less_than_x_seconds, :count => 10
                when 10..19 then locale.t :less_than_x_seconds, :count => 20
                when 20..39 then locale.t :half_a_minute
                when 40..59 then locale.t :less_than_x_minutes, :count => 1
                else             locale.t :x_minutes,           :count => 1
              end

            when 2...45           then locale.t :x_minutes,      :count => distance_in_minutes
            when 45...90          then locale.t :about_x_hours,  :count => 1
            when 90...1440        then locale.t :about_x_hours,  :count => (distance_in_minutes.to_f / 60.0).round
            when 1440...2520      then locale.t :x_days,         :count => 1
            when 2520...43200     then locale.t :x_days,         :count => (distance_in_minutes.to_f / 1440.0).round
            when 43200...86400    then locale.t :about_x_months, :count => (distance_in_minutes.to_f / 43200.0).round
            when 86400...525600   then locale.t :x_months,       :count => (distance_in_minutes.to_f / 43200.0).round
            else
              if from_time.acts_like?(:time) && to_time.acts_like?(:time)
                fyear = from_time.year
                fyear += 1 if from_time.month >= 3
                tyear = to_time.year
                tyear -= 1 if to_time.month < 3
                leap_years = (fyear > tyear) ? 0 : (fyear..tyear).count{|x| Date.leap?(x)}
                minute_offset_for_leap_year = leap_years * 1440
                minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year
              else
                minutes_with_offset = distance_in_minutes
              end
              remainder                   = (minutes_with_offset % MINUTES_IN_YEAR)
              distance_in_years           = (minutes_with_offset.div MINUTES_IN_YEAR)
              if remainder < MINUTES_IN_QUARTER_YEAR
                locale.t(:about_x_years,  :count => distance_in_years)
              elsif remainder < MINUTES_IN_THREE_QUARTERS_YEAR
                locale.t(:over_x_years,   :count => distance_in_years)
              else
                locale.t(:almost_x_years, :count => distance_in_years + 1)
              end
          end
        end
      end

      def time_ago_in_words(from_time, options = {})
        distance_of_time_in_words(from_time, Time.now, options)
      end

      alias_method :distance_of_time_in_words_to_now, :time_ago_in_words

      def date_select(object_name, method, options = {}, html_options = {})
        Tags::DateSelect.new(object_name, method, self, options, html_options).render
      end

      def time_select(object_name, method, options = {}, html_options = {})
        Tags::TimeSelect.new(object_name, method, self, options, html_options).render
      end

      def datetime_select(object_name, method, options = {}, html_options = {})
        Tags::DatetimeSelect.new(object_name, method, self, options, html_options).render
      end

      def select_datetime(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_datetime
      end

      def select_date(date = Date.current, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_date
      end

      def select_time(datetime = Time.current, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_time
      end

      def select_second(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_second
      end

      def select_minute(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_minute
      end

      def select_hour(datetime, options = {}, html_options = {})
        DateTimeSelector.new(datetime, options, html_options).select_hour
      end

      def select_day(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_day
      end

      def select_month(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_month
      end

      def select_year(date, options = {}, html_options = {})
        DateTimeSelector.new(date, options, html_options).select_year
      end

      def time_tag(date_or_time, *args, &block)
        options  = args.extract_options!
        format   = options.delete(:format) || :long
        content  = args.first || I18n.l(date_or_time, :format => format)
        datetime = date_or_time.acts_like?(:time) ? date_or_time.xmlschema : date_or_time.iso8601

        content_tag(:time, content, options.reverse_merge(:datetime => datetime), &block)
      end
    end

    class DateTimeSelector #:nodoc:
      include ActionView::Helpers::TagHelper

      DEFAULT_PREFIX = 'date'.freeze
      POSITION = {
        :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5, :second => 6
      }.freeze

      AMPM_TRANSLATION = Hash[
        [[0, "12 AM"], [1, "01 AM"], [2, "02 AM"], [3, "03 AM"],
         [4, "04 AM"], [5, "05 AM"], [6, "06 AM"], [7, "07 AM"],
         [8, "08 AM"], [9, "09 AM"], [10, "10 AM"], [11, "11 AM"],
         [12, "12 PM"], [13, "01 PM"], [14, "02 PM"], [15, "03 PM"],
         [16, "04 PM"], [17, "05 PM"], [18, "06 PM"], [19, "07 PM"],
         [20, "08 PM"], [21, "09 PM"], [22, "10 PM"], [23, "11 PM"]]
      ].freeze

      def initialize(datetime, options = {}, html_options = {})
        @options      = options.dup
        @html_options = html_options.dup
        @datetime     = datetime
        @options[:datetime_separator] ||= ' &mdash; '
        @options[:time_separator]     ||= ' : '
      end

      def select_datetime
        order = date_order.dup
        order -= [:hour, :minute, :second]
        @options[:discard_year]   ||= true unless order.include?(:year)
        @options[:discard_month]  ||= true unless order.include?(:month)
        @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)
        @options[:discard_minute] ||= true if @options[:discard_hour]
        @options[:discard_second] ||= true unless @options[:include_seconds] && !@options[:discard_minute]

        set_day_if_discarded

        if @options[:tag] && @options[:ignore_date]
          select_time
        else
          [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }
          order += [:hour, :minute, :second] unless @options[:discard_hour]

          build_selects_from_types(order)
        end
      end

      def select_date
        order = date_order.dup

        @options[:discard_hour]     = true
        @options[:discard_minute]   = true
        @options[:discard_second]   = true

        @options[:discard_year]   ||= true unless order.include?(:year)
        @options[:discard_month]  ||= true unless order.include?(:month)
        @options[:discard_day]    ||= true if @options[:discard_month] || !order.include?(:day)

        set_day_if_discarded

        [:day, :month, :year].each { |o| order.unshift(o) unless order.include?(o) }

        build_selects_from_types(order)
      end

      def select_time
        order = []

        @options[:discard_month]    = true
        @options[:discard_year]     = true
        @options[:discard_day]      = true
        @options[:discard_second] ||= true unless @options[:include_seconds]

        order += [:year, :month, :day] unless @options[:ignore_date]

        order += [:hour, :minute]
        order << :second if @options[:include_seconds]

        build_selects_from_types(order)
      end

      def select_second
        if @options[:use_hidden] || @options[:discard_second]
          build_hidden(:second, sec) if @options[:include_seconds]
        else
          build_options_and_select(:second, sec)
        end
      end

      def select_minute
        if @options[:use_hidden] || @options[:discard_minute]
          build_hidden(:minute, min)
        else
          build_options_and_select(:minute, min, :step => @options[:minute_step])
        end
      end

      def select_hour
        if @options[:use_hidden] || @options[:discard_hour]
          build_hidden(:hour, hour)
        else
          options         = {}
          options[:ampm]  = @options[:ampm] || false
          options[:start] = @options[:start_hour] || 0
          options[:end]   = @options[:end_hour] || 23
          build_options_and_select(:hour, hour, options)
        end
      end

      def select_day
        if @options[:use_hidden] || @options[:discard_day]
          build_hidden(:day, day || 1)
        else
          build_options_and_select(:day, day, :start => 1, :end => 31, :leading_zeros => false, :use_two_digit_numbers => @options[:use_two_digit_numbers])
        end
      end

      def select_month
        if @options[:use_hidden] || @options[:discard_month]
          build_hidden(:month, month || 1)
        else
          month_options = []
          1.upto(12) do |month_number|
            options = { :value => month_number }
            options[:selected] = "selected" if month == month_number
            month_options << content_tag(:option, month_name(month_number), options) + "\n"
          end
          build_select(:month, month_options.join)
        end
      end

      def select_year
        if !@datetime || @datetime == 0
          val = '1'
          middle_year = Date.today.year
        else
          val = middle_year = year
        end

        if @options[:use_hidden] || @options[:discard_year]
          build_hidden(:year, val)
        else
          options                     = {}
          options[:start]             = @options[:start_year] || middle_year - 5
          options[:end]               = @options[:end_year] || middle_year + 5
          options[:step]              = options[:start] < options[:end] ? 1 : -1
          options[:leading_zeros]     = false
          options[:max_years_allowed] = @options[:max_years_allowed] || 1000

          if (options[:end] - options[:start]).abs > options[:max_years_allowed]
            raise ArgumentError, "There are too many years options to be built. Are you sure you haven't mistyped something? You can provide the :max_years_allowed parameter."
          end

          build_options_and_select(:year, val, options)
        end
      end

      private
        %w( sec min hour day month year ).each do |method|
          #nodyna <define_method-1222> <DM MODERATE (array)>
          define_method(method) do
            #nodyna <send-1223> <SD MODERATE (array)>
            @datetime.kind_of?(Numeric) ? @datetime : @datetime.send(method) if @datetime
          end
        end

        def set_day_if_discarded
          if @datetime && @options[:discard_day]
            @datetime = @datetime.change(:day => 1)
          end
        end

        def month_names
          @month_names ||= begin
            month_names = @options[:use_month_names] || translated_month_names
            month_names.unshift(nil) if month_names.size < 13
            month_names
          end
        end

        def translated_month_names
          key = @options[:use_short_month] ? :'date.abbr_month_names' : :'date.month_names'
          I18n.translate(key, :locale => @options[:locale])
        end

        def month_name(number)
          if @options[:use_month_numbers]
            number
          elsif @options[:use_two_digit_numbers]
            '%02d' % number
          elsif @options[:add_month_numbers]
            "#{number} - #{month_names[number]}"
          elsif format_string = @options[:month_format_string]
            format_string % {number: number, name: month_names[number]}
          else
            month_names[number]
          end
        end

        def date_order
          @date_order ||= @options[:order] || translated_date_order
        end

        def translated_date_order
          date_order = I18n.translate(:'date.order', :locale => @options[:locale], :default => [])
          date_order = date_order.map { |element| element.to_sym }

          forbidden_elements = date_order - [:year, :month, :day]
          if forbidden_elements.any?
            raise StandardError,
              "#{@options[:locale]}.date.order only accepts :year, :month and :day"
          end

          date_order
        end

        def build_options_and_select(type, selected, options = {})
          build_select(type, build_options(selected, options))
        end

        def build_options(selected, options = {})
          options = {
            leading_zeros: true, ampm: false, use_two_digit_numbers: false
          }.merge!(options)

          start         = options.delete(:start) || 0
          stop          = options.delete(:end) || 59
          step          = options.delete(:step) || 1
          leading_zeros = options.delete(:leading_zeros)

          select_options = []
          start.step(stop, step) do |i|
            value = leading_zeros ? sprintf("%02d", i) : i
            tag_options = { :value => value }
            tag_options[:selected] = "selected" if selected == i
            text = options[:use_two_digit_numbers] ? sprintf("%02d", i) : value
            text = options[:ampm] ? AMPM_TRANSLATION[i] : text
            select_options << content_tag(:option, text, tag_options)
          end

          (select_options.join("\n") + "\n").html_safe
        end

        def build_select(type, select_options_as_html)
          select_options = {
            :id => input_id_from_type(type),
            :name => input_name_from_type(type)
          }.merge!(@html_options)
          select_options[:disabled] = 'disabled' if @options[:disabled]
          select_options[:class] = [select_options[:class], type].compact.join(' ') if @options[:with_css_classes]

          select_html = "\n"
          select_html << content_tag(:option, '', :value => '') + "\n" if @options[:include_blank]
          select_html << prompt_option_tag(type, @options[:prompt]) + "\n" if @options[:prompt]
          select_html << select_options_as_html

          (content_tag(:select, select_html.html_safe, select_options) + "\n").html_safe
        end

        def prompt_option_tag(type, options)
          prompt = case options
            when Hash
              default_options = {:year => false, :month => false, :day => false, :hour => false, :minute => false, :second => false}
              default_options.merge!(options)[type.to_sym]
            when String
              options
            else
              I18n.translate(:"datetime.prompts.#{type}", :locale => @options[:locale])
          end

          prompt ? content_tag(:option, prompt, :value => '') : ''
        end

        def build_hidden(type, value)
          select_options = {
            :type => "hidden",
            :id => input_id_from_type(type),
            :name => input_name_from_type(type),
            :value => value
          }.merge!(@html_options.slice(:disabled))
          select_options[:disabled] = 'disabled' if @options[:disabled]

          tag(:input, select_options) + "\n".html_safe
        end

        def input_name_from_type(type)
          prefix = @options[:prefix] || ActionView::Helpers::DateTimeSelector::DEFAULT_PREFIX
          prefix += "[#{@options[:index]}]" if @options.has_key?(:index)

          field_name = @options[:field_name] || type
          if @options[:include_position]
            field_name += "(#{ActionView::Helpers::DateTimeSelector::POSITION[type]}i)"
          end

          @options[:discard_type] ? prefix : "#{prefix}[#{field_name}]"
        end

        def input_id_from_type(type)
          id = input_name_from_type(type).gsub(/([\[\(])|(\]\[)/, '_').gsub(/[\]\)]/, '')
          id = @options[:namespace] + '_' + id if @options[:namespace]

          id
        end

        def build_selects_from_types(order)
          select = ''
          first_visible = order.find { |type| !@options[:"discard_#{type}"] }
          order.reverse_each do |type|
            separator = separator(type) unless type == first_visible # don't add before first visible field
            #nodyna <send-1224> <SD MODERATE (array)>
            select.insert(0, separator.to_s + send("select_#{type}").to_s)
          end
          select.html_safe
        end

        def separator(type)
          return "" if @options[:use_hidden]

          case type
            when :year, :month, :day
              @options[:"discard_#{type}"] ? "" : @options[:date_separator]
            when :hour
              (@options[:discard_year] && @options[:discard_day]) ? "" : @options[:datetime_separator]
            when :minute, :second
              @options[:"discard_#{type}"] ? "" : @options[:time_separator]
          end
        end
    end

    class FormBuilder
      def date_select(method, options = {}, html_options = {})
        @template.date_select(@object_name, method, objectify_options(options), html_options)
      end

      def time_select(method, options = {}, html_options = {})
        @template.time_select(@object_name, method, objectify_options(options), html_options)
      end

      def datetime_select(method, options = {}, html_options = {})
        @template.datetime_select(@object_name, method, objectify_options(options), html_options)
      end
    end
  end
end
