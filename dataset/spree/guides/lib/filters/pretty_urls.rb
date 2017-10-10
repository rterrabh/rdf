require 'nanoc'

class PrettyUrls < Nanoc::Filter

  identifier :pretty_urls

  def run(content, params={})



    content = content.gsub /\[([^\]]*)\]\(([^[#\)]\.]+)(#\S*)?\)/ do
      "[#{$1}](#{$2}.html#{$3})"
    end

    content
  end
end
