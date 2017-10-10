module TemplateWrapper
  def safe_wrap(input)
    "<div class='bogus-wrapper'><notextile>#{input}</notextile></div>"
  end
  def unwrap(input)
    input.gsub /<div class='bogus-wrapper'><notextile>(.+?)<\/notextile><\/div>/m do
      $1
    end
  end
end


module Jekyll
  class RawTag < Liquid::Block
    def parse(tokens)
      @nodelist ||= []
      @nodelist.clear

      while token = tokens.shift
        if token =~ FullToken
          if block_delimiter == $1
            end_tag
            return
          end
        end
        @nodelist << token if not token.empty?
      end
    end
  end
end

Liquid::Template.register_tag('raw', Jekyll::RawTag)
