module Gitlab
  module Markdown
    class ExternalIssueReferenceFilter < ReferenceFilter
      def self.references_in(text)
        text.gsub(ExternalIssue.reference_pattern) do |match|
          yield match, $~[:issue]
        end
      end

      def call
        return doc if project.nil? || project.default_issues_tracker?

        replace_text_nodes_matching(ExternalIssue.reference_pattern) do |content|
          issue_link_filter(content)
        end
      end

      def issue_link_filter(text)
        project = context[:project]

        self.class.references_in(text) do |match, issue|
          url = url_for_issue(issue, project, only_path: context[:only_path])

          title = escape_once("Issue in #{project.external_issue_tracker.title}")
          klass = reference_class(:issue)

          %(<a href="#{url}"
               title="#{title}"
               class="#{klass}">#{match}</a>)
        end
      end

      def url_for_issue(*args)
        IssuesHelper.url_for_issue(*args)
      end
    end
  end
end
