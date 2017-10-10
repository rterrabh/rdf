module Gitlab
  module Markdown
    class IssueReferenceFilter < ReferenceFilter
      include CrossProjectReference

      def self.references_in(text)
        text.gsub(Issue.reference_pattern) do |match|
          yield match, $~[:issue].to_i, $~[:project]
        end
      end

      def call
        replace_text_nodes_matching(Issue.reference_pattern) do |content|
          issue_link_filter(content)
        end
      end

      def issue_link_filter(text)
        self.class.references_in(text) do |match, id, project_ref|
          project = self.project_from_ref(project_ref)

          if project && issue = project.get_issue(id)
            push_result(:issue, issue)

            url = url_for_issue(id, project, only_path: context[:only_path])

            title = escape_once("Issue: #{issue.title}")
            klass = reference_class(:issue)
            data  = data_attribute(project.id)

            %(<a href="#{url}" #{data}
                 title="#{title}"
                 class="#{klass}">#{match}</a>)
          else
            match
          end
        end
      end

      def url_for_issue(*args)
        IssuesHelper.url_for_issue(*args)
      end
    end
  end
end
