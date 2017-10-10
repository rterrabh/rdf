module Gitlab
  module MarkupHelper
    module_function

    def markup?(filename)
      gitlab_markdown?(filename) ||
        asciidoc?(filename) ||
        filename.downcase.end_with?(*%w(.textile .rdoc .org .creole .wiki
                                        .mediawiki .rst))
    end

    def gitlab_markdown?(filename)
      filename.downcase.end_with?(*%w(.mdown .mkd .mkdn .md .markdown))
    end

    def asciidoc?(filename)
      filename.downcase.end_with?(*%w(.adoc .ad .asciidoc))
    end

    def plain?(filename)
      filename.downcase.end_with?('.txt') ||
        filename.downcase == 'readme'
    end

    def previewable?(filename)
      markup?(filename)
    end
  end
end
