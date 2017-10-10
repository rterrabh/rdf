require 'erubis'

module ActionView
  class Template
    module Handlers
      class Erubis < ::Erubis::Eruby
        def add_preamble(src)
          @newline_pending = 0
          src << "@output_buffer = output_buffer || ActionView::OutputBuffer.new;"
        end

        def add_text(src, text)
          return if text.empty?

          if text == "\n"
            @newline_pending += 1
          else
            src << "@output_buffer.safe_append='"
            src << "\n" * @newline_pending if @newline_pending > 0
            src << escape_text(text)
            src << "'.freeze;"

            @newline_pending = 0
          end
        end

        def add_expr(src, code, indicator)
          case indicator
          when '=='
            add_expr_escaped(src, code)
          else
            super
          end
        end

        BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

        def add_expr_literal(src, code)
          flush_newline_if_pending(src)
          if code =~ BLOCK_EXPR
            src << '@output_buffer.append= ' << code
          else
            src << '@output_buffer.append=(' << code << ');'
          end
        end

        def add_expr_escaped(src, code)
          flush_newline_if_pending(src)
          if code =~ BLOCK_EXPR
            src << "@output_buffer.safe_expr_append= " << code
          else
            src << "@output_buffer.safe_expr_append=(" << code << ");"
          end
        end

        def add_stmt(src, code)
          flush_newline_if_pending(src)
          super
        end

        def add_postamble(src)
          flush_newline_if_pending(src)
          src << '@output_buffer.to_s'
        end

        def flush_newline_if_pending(src)
          if @newline_pending > 0
            src << "@output_buffer.safe_append='#{"\n" * @newline_pending}'.freeze;"
            @newline_pending = 0
          end
        end
      end

      class ERB
        class_attribute :erb_trim_mode
        self.erb_trim_mode = '-'

        class_attribute :erb_implementation
        self.erb_implementation = Erubis

        class_attribute :escape_whitelist
        self.escape_whitelist = ["text/plain"]

        ENCODING_TAG = Regexp.new("\\A(<%#{ENCODING_FLAG}-?%>)[ \\t]*")

        def self.call(template)
          new.call(template)
        end

        def supports_streaming?
          true
        end

        def handles_encoding?
          true
        end

        def call(template)
          template_source = template.source.dup.force_encoding(Encoding::ASCII_8BIT)

          erb = template_source.gsub(ENCODING_TAG, '')
          encoding = $2

          erb.force_encoding valid_encoding(template.source.dup, encoding)

          erb.encode!

          self.class.erb_implementation.new(
            erb,
            :escape => (self.class.escape_whitelist.include? template.type),
            :trim => (self.class.erb_trim_mode == "-")
          ).src
        end

      private

        def valid_encoding(string, encoding)
          string.force_encoding(encoding) if encoding

          return string.encoding if string.valid_encoding?

          raise WrongEncodingError.new(string, string.encoding)
        end
      end
    end
  end
end
