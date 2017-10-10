
module Jekyll

  class PullquoteTag < Liquid::Block
    def initialize(tag_name, markup, tokens)
      @align = (markup =~ /left/i) ? "left" : "right"
      super
    end

    def render(context)
      output = super
      if output.join =~ /\{"\s*(.+)\s*"\}/
        @quote = RubyPants.new($1).to_html
        "<span class='pullquote-#{@align}' data-pullquote='#{@quote}'>#{output.join.gsub(/\{"\s*|\s*"\}/, '')}</span>"
      else
        return "Surround your pullquote like this {\" text to be quoted \"}"
      end
    end
  end
end

Liquid::Template.register_tag('pullquote', Jekyll::PullquoteTag)
