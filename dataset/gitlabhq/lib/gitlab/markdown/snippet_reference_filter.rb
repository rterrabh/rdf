module Gitlab
  module Markdown
    class SnippetReferenceFilter < ReferenceFilter
      include CrossProjectReference

      def self.references_in(text)
        text.gsub(Snippet.reference_pattern) do |match|
          yield match, $~[:snippet].to_i, $~[:project]
        end
      end

      def call
        replace_text_nodes_matching(Snippet.reference_pattern) do |content|
          snippet_link_filter(content)
        end
      end

      def snippet_link_filter(text)
        self.class.references_in(text) do |match, id, project_ref|
          project = self.project_from_ref(project_ref)

          if project && snippet = project.snippets.find_by(id: id)
            push_result(:snippet, snippet)

            title = escape_once("Snippet: #{snippet.title}")
            klass = reference_class(:snippet)
            data  = data_attribute(project.id)

            url = url_for_snippet(snippet, project)

            %(<a href="#{url}" #{data}
                 title="#{title}"
                 class="#{klass}">#{match}</a>)
          else
            match
          end
        end
      end

      def url_for_snippet(snippet, project)
        h = Rails.application.routes.url_helpers
        h.namespace_project_snippet_url(project.namespace, project, snippet,
                                        only_path: context[:only_path])
      end
    end
  end
end
