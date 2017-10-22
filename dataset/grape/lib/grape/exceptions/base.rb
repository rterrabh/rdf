module Grape
  module Exceptions
    class Base < StandardError
      BASE_MESSAGES_KEY = 'grape.errors.messages'
      BASE_ATTRIBUTES_KEY = 'grape.errors.attributes'
      FALLBACK_LOCALE = :en

      attr_reader :status, :message, :headers

      def initialize(args = {})
        @status = args[:status] || nil
        @message = args[:message] || nil
        @headers = args[:headers] || nil
      end

      def [](index)
        #nodyna <send-2829> <SD COMPLEX (change-prone variables)>
        send index
      end

      protected

      def compose_message(key, attributes = {})
        short_message = translate_message(key, attributes)
        if short_message.is_a? Hash
          @problem = problem(key, attributes)
          @summary = summary(key, attributes)
          @resolution = resolution(key, attributes)
          [['Problem', @problem], ['Summary', @summary], ['Resolution', @resolution]].reduce('') do |message, detail_array|
            message << "\n#{detail_array[0]}:\n  #{detail_array[1]}" unless detail_array[1].blank?
            message
          end
        else
          short_message
        end
      end

      def problem(key, attributes)
        translate_message("#{key}.problem", attributes)
      end

      def summary(key, attributes)
        translate_message("#{key}.summary", attributes)
      end

      def resolution(key, attributes)
        translate_message("#{key}.resolution", attributes)
      end

      def translate_attributes(keys, options = {})
        keys.map do |key|
          translate("#{BASE_ATTRIBUTES_KEY}.#{key}", { default: key }.merge(options))
        end.join(', ')
      end

      def translate_attribute(key, options = {})
        translate("#{BASE_ATTRIBUTES_KEY}.#{key}", { default: key }.merge(options))
      end

      def translate_message(key, options = {})
        translate("#{BASE_MESSAGES_KEY}.#{key}", { default: '' }.merge(options))
      end

      def translate(key, options = {})
        message = ::I18n.translate(key, options)
        message.present? ? message : ::I18n.translate(key, options.merge(locale: FALLBACK_LOCALE))
      end
    end
  end
end
