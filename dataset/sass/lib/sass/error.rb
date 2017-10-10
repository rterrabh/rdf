module Sass
  class SyntaxError < StandardError
    attr_accessor :sass_backtrace

    attr_accessor :sass_template

    def initialize(msg, attrs = {})
      @message = msg
      @sass_backtrace = []
      add_backtrace(attrs)
    end

    def sass_filename
      sass_backtrace.first[:filename]
    end

    def sass_mixin
      sass_backtrace.first[:mixin]
    end

    def sass_line
      sass_backtrace.first[:line]
    end

    def add_backtrace(attrs)
      sass_backtrace << attrs.reject {|k, v| v.nil?}
    end

    def modify_backtrace(attrs)
      attrs = attrs.reject {|k, v| v.nil?}
      (0...sass_backtrace.size).to_a.reverse.each do |i|
        entry = sass_backtrace[i]
        sass_backtrace[i] = attrs.merge(entry)
        attrs.reject! {|k, v| entry.include?(k)}
        break if attrs.empty?
      end
    end

    def to_s
      @message
    end

    def backtrace
      return nil if super.nil?
      return super if sass_backtrace.all? {|h| h.empty?}
      sass_backtrace.map do |h|
        "#{h[:filename] || "(sass)"}:#{h[:line]}" +
          (h[:mixin] ? ":in `#{h[:mixin]}'" : "")
      end + super
    end

    def sass_backtrace_str(default_filename = "an unknown file")
      lines = message.split("\n")
      msg = lines[0] + lines[1..-1].
        map {|l| "\n" + (" " * "Error: ".size) + l}.join
      "Error: #{msg}" +
        Sass::Util.enum_with_index(sass_backtrace).map do |entry, i|
          "\n        #{i == 0 ? "on" : "from"} line #{entry[:line]}" +
            " of #{entry[:filename] || default_filename}" +
            (entry[:mixin] ? ", in `#{entry[:mixin]}'" : "")
        end.join
    end

    class << self
      def exception_to_css(e, line_offset = 1)
        header = header_string(e, line_offset)

        <<END
/*

Backtrace:\n#{e.backtrace.join("\n").gsub("*/", "*\\/")}
*/
body:before {
  white-space: pre;
  font-family: monospace;
  content: "#{header.gsub('"', '\"').gsub("\n", '\\A ')}"; }
END
      end

      private

      def header_string(e, line_offset)
        unless e.is_a?(Sass::SyntaxError) && e.sass_line && e.sass_template
          return "#{e.class}: #{e.message}"
        end

        line_num = e.sass_line + 1 - line_offset
        min = [line_num - 6, 0].max
        section = e.sass_template.rstrip.split("\n")[min ... line_num + 5]
        return e.sass_backtrace_str if section.nil? || section.empty?

        e.sass_backtrace_str + "\n\n" + Sass::Util.enum_with_index(section).
          map {|line, i| "#{line_offset + min + i}: #{line}"}.join("\n")
      end
    end
  end

  class UnitConversionError < SyntaxError; end
end
