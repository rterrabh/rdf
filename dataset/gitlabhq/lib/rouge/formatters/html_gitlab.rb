require 'cgi'

module Rouge
  module Formatters
    class HTMLGitlab < Rouge::Formatter
      tag 'html_gitlab'

      def initialize(
          nowrap: false,
          cssclass: 'highlight',
          linenos: nil,
          linenostart: 1,
          lineanchors: false,
          lineanchorsid: 'L',
          anchorlinenos: false,
          inline_theme: nil
        )
        @nowrap = nowrap
        @cssclass = cssclass
        @linenos = linenos
        @linenostart = linenostart
        @lineanchors = lineanchors
        @lineanchorsid = lineanchorsid
        @anchorlinenos = anchorlinenos
        @inline_theme = Theme.find(inline_theme).new if inline_theme.is_a?(String)
      end

      def render(tokens)
        case @linenos
        when 'table'
          render_tableized(tokens)
        when 'inline'
          render_untableized(tokens)
        else
          render_untableized(tokens)
        end
      end

      alias_method :format, :render

      private

      def render_untableized(tokens)
        data = process_tokens(tokens)

        html = ''
        html << "<pre class=\"#{@cssclass}\"><code>" unless @nowrap
        html << wrap_lines(data[:code])
        html << "</code></pre>\n" unless @nowrap
        html
      end

      def render_tableized(tokens)
        data = process_tokens(tokens)

        html = ''
        html << "<div class=\"#{@cssclass}\">" unless @nowrap
        html << '<table><tbody>'
        html << "<td class=\"linenos\"><pre>"
        html << wrap_linenos(data[:numbers])
        html << '</pre></td>'
        html << "<td class=\"lines\"><pre><code>"
        html << wrap_lines(data[:code])
        html << '</code></pre></td>'
        html << '</tbody></table>'
        html << '</div>' unless @nowrap
        html
      end

      def process_tokens(tokens)
        rendered = []
        current_line = ''

        tokens.each do |tok, val|
          val.lines.each do |line|
            stripped = line.chomp
            current_line << span(tok, stripped)

            if line.end_with?("\n")
              rendered << current_line
              current_line = ''
            end
          end
        end

        rendered << current_line if current_line.present?

        num_lines = rendered.size
        numbers = (@linenostart..num_lines + @linenostart - 1).to_a

        { numbers: numbers, code: rendered }
      end

      def wrap_linenos(numbers)
        if @anchorlinenos
          numbers.map! do |number|
            "<a href=\"##{@lineanchorsid}#{number}\">#{number}</a>"
          end
        end
        numbers.join("\n")
      end

      def wrap_lines(lines)
        if @lineanchors
          lines = lines.each_with_index.map do |line, index|
            number = index + @linenostart

            if @linenos == 'inline'
              "<a name=\"L#{number}\"></a>" \
              "<span class=\"linenos\">#{number}</span>" \
              "<span id=\"#{@lineanchorsid}#{number}\" class=\"line\">#{line}" \
              '</span>'
            else
              "<span id=\"#{@lineanchorsid}#{number}\" class=\"line\">#{line}" \
              '</span>'
            end
          end
          lines.join("\n")
        else
          if @linenos == 'inline'
            lines = lines.each_with_index.map do |line, index|
              number = index + @linenostart
              "<span class=\"linenos\">#{number}</span>#{line}"
            end
            lines.join("\n")
          else
            lines.join("\n")
          end
        end
      end

      def span(tok, val)
        val = CGI.escapeHTML(val)

        if tok.shortname.empty?
          val
        else
          if @inline_theme
            rules = @inline_theme.style_for(tok).rendered_rules
            "<span style=\"#{rules.to_a.join(';')}\"#{val}</span>"
          else
            "<span class=\"#{tok.shortname}\">#{val}</span>"
          end
        end
      end
    end
  end
end
