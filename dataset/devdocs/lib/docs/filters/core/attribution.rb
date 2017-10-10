module Docs
  class AttributionFilter < Filter
    def call
      html << attribution_html if attribution
      html
    end

    def attribution
      context[:attribution]
    end

    def attribution_html
      <<-HTML.strip_heredoc
      <div class="_attribution">
        <p class="_attribution-p">
        </p>
      </div>
      HTML
    end

    def attribution_link
      unless base_url.host == 'localhost'
        %(<a href="#{current_url}" class="_attribution-link">#{current_url}</a>)
      end
    end
  end
end
