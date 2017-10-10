require './plugins/backtick_code_block'
require './plugins/post_filters'
require './plugins/raw'
require './plugins/date'
require 'rubypants'

module OctopressFilters
  include BacktickCodeBlock
  include TemplateWrapper
  def pre_filter(input)
    input = render_code_block(input)
    input.gsub /(<figure.+?>.+?<\/figure>)/m do
      safe_wrap($1)
    end
  end
  def post_filter(input)
    input = unwrap(input)
    RubyPants.new(input).to_html
  end
end

module Jekyll
  class ContentFilters < PostFilter
    include OctopressFilters
    def pre_render(post)
      post.content = pre_filter(post.content)
    end
    def post_render(post)
      post.content = post_filter(post.content)
    end
  end
end


module OctopressLiquidFilters
  include Octopress::Date

  def excerpt(input)
    if input.index(/<!--\s*more\s*-->/i)
      input.split(/<!--\s*more\s*-->/i)[0]
    else
      input
    end
  end

  def has_excerpt(input)
    input =~ /<!--\s*more\s*-->/i ? true : false
  end

  def summary(input)
    if input.index(/\n\n/)
      input.split(/\n\n/)[0]
    else
      input
    end
  end

  def raw_content(input)
    /<div class="entry-content">(?<content>[\s\S]*?)<\/div>\s*<(footer|\/article)>/ =~ input
    return (content.nil?) ? input : content
  end

  def cdata_escape(input)
    input.gsub(/<!\[CDATA\[/, '&lt;![CDATA[').gsub(/\]\]>/, ']]&gt;')
  end

  def expand_urls(input, url='')
    url ||= '/'
    input.gsub /(\s+(href|src)\s*=\s*["|']{1})(\/[^\"'>]*)/ do
      $1+url+$3
    end
  end

  def truncate(input, length)
    if input.length > length && input[0..(length-1)] =~ /(.+)\b.+$/im
      $1.strip + ' &hellip;'
    else
      input
    end
  end

  def truncatewords(input, length)
    truncate = input.split(' ')
    if truncate.length > length
      truncate[0..length-1].join(' ').strip + ' &hellip;'
    else
      input
    end
  end

  def condense_spaces(input)
    input.gsub(/\s{2,}/, ' ')
  end

  def strip_slash(input)
    if input =~ /(.+)\/$|^\/$/
      input = $1
    end
    input
  end

  def shorthand_url(input)
    input.gsub /(https?:\/\/)(\S+)/ do
      $2
    end
  end

  def titlecase(input)
    input.titlecase
  end

end
Liquid::Template.register_filter OctopressLiquidFilters

