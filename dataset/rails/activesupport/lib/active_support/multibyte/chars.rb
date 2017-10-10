require 'active_support/json'
require 'active_support/core_ext/string/access'
require 'active_support/core_ext/string/behavior'
require 'active_support/core_ext/module/delegation'

module ActiveSupport #:nodoc:
  module Multibyte #:nodoc:
    class Chars
      include Comparable
      attr_reader :wrapped_string
      alias to_s wrapped_string
      alias to_str wrapped_string

      delegate :<=>, :=~, :acts_like_string?, :to => :wrapped_string

      def initialize(string)
        @wrapped_string = string
        @wrapped_string.force_encoding(Encoding::UTF_8) unless @wrapped_string.frozen?
      end

      def method_missing(method, *args, &block)
        result = @wrapped_string.__send__(method, *args, &block)
        if method.to_s =~ /!$/
          self if result
        else
          result.kind_of?(String) ? chars(result) : result
        end
      end

      def respond_to_missing?(method, include_private)
        @wrapped_string.respond_to?(method, include_private)
      end

      def self.consumes?(string)
        string.encoding == Encoding::UTF_8
      end

      def split(*args)
        @wrapped_string.split(*args).map { |i| self.class.new(i) }
      end

      def slice!(*args)
        chars(@wrapped_string.slice!(*args))
      end

      def reverse
        chars(Unicode.unpack_graphemes(@wrapped_string).reverse.flatten.pack('U*'))
      end

      def limit(limit)
        slice(0...translate_offset(limit))
      end

      def upcase
        chars Unicode.upcase(@wrapped_string)
      end

      def downcase
        chars Unicode.downcase(@wrapped_string)
      end

      def swapcase
        chars Unicode.swapcase(@wrapped_string)
      end

      def capitalize
        (slice(0) || chars('')).upcase + (slice(1..-1) || chars('')).downcase
      end

      def titleize
        chars(downcase.to_s.gsub(/\b('?\S)/u) { Unicode.upcase($1)})
      end
      alias_method :titlecase, :titleize

      def normalize(form = nil)
        chars(Unicode.normalize(@wrapped_string, form))
      end

      def decompose
        chars(Unicode.decompose(:canonical, @wrapped_string.codepoints.to_a).pack('U*'))
      end

      def compose
        chars(Unicode.compose(@wrapped_string.codepoints.to_a).pack('U*'))
      end

      def grapheme_length
        Unicode.unpack_graphemes(@wrapped_string).length
      end

      def tidy_bytes(force = false)
        chars(Unicode.tidy_bytes(@wrapped_string, force))
      end

      def as_json(options = nil) #:nodoc:
        to_s.as_json(options)
      end

      %w(capitalize downcase reverse tidy_bytes upcase).each do |method|
        #nodyna <define_method-1107> <DM MODERATE (array)>
        define_method("#{method}!") do |*args|
          #nodyna <send-1108> <SD MODERATE (array)>
          @wrapped_string = send(method, *args).to_s
          self
        end
      end

      protected

        def translate_offset(byte_offset) #:nodoc:
          return nil if byte_offset.nil?
          return 0   if @wrapped_string == ''

          begin
            @wrapped_string.byteslice(0...byte_offset).unpack('U*').length
          rescue ArgumentError
            byte_offset -= 1
            retry
          end
        end

        def chars(string) #:nodoc:
          self.class.new(string)
        end
    end
  end
end
