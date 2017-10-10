module ActionMailer
  module MailHelper
    def block_format(text)
      formatted = text.split(/\n\r?\n/).collect { |paragraph|
        format_paragraph(paragraph)
      }.join("\n\n")

      formatted.gsub!(/[ ]*([*]+) ([^*]*)/) { "  #{$1} #{$2.strip}\n" }
      formatted.gsub!(/[ ]*([#]+) ([^#]*)/) { "  #{$1} #{$2.strip}\n" }

      formatted
    end

    def mailer
      @_controller
    end

    def message
      @_message
    end

    def attachments
      mailer.attachments
    end

    def format_paragraph(text, len = 72, indent = 2)
      sentences = [[]]

      text.split.each do |word|
        if sentences.first.present? && (sentences.last + [word]).join(' ').length > len
          sentences << [word]
        else
          sentences.last << word
        end
      end

      indentation = " " * indent
      sentences.map! { |sentence|
        "#{indentation}#{sentence.join(' ')}"
      }.join "\n"
    end
  end
end
