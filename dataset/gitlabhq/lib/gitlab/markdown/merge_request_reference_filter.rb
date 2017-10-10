module Gitlab
  module Markdown
    class MergeRequestReferenceFilter < ReferenceFilter
      include CrossProjectReference

      def self.references_in(text)
        text.gsub(MergeRequest.reference_pattern) do |match|
          yield match, $~[:merge_request].to_i, $~[:project]
        end
      end

      def call
        replace_text_nodes_matching(MergeRequest.reference_pattern) do |content|
          merge_request_link_filter(content)
        end
      end

      def merge_request_link_filter(text)
        self.class.references_in(text) do |match, id, project_ref|
          project = self.project_from_ref(project_ref)

          if project && merge_request = project.merge_requests.find_by(iid: id)
            push_result(:merge_request, merge_request)

            title = escape_once("Merge Request: #{merge_request.title}")
            klass = reference_class(:merge_request)
            data  = data_attribute(project.id)

            url = url_for_merge_request(merge_request, project)

            %(<a href="#{url}" #{data}
                 title="#{title}"
                 class="#{klass}">#{match}</a>)
          else
            match
          end
        end
      end

      def url_for_merge_request(mr, project)
        h = Rails.application.routes.url_helpers
        h.namespace_project_merge_request_url(project.namespace, project, mr,
                                            only_path: context[:only_path])
      end
    end
  end
end
