module Gitlab
  module Markdown
    class LabelReferenceFilter < ReferenceFilter
      def self.references_in(text)
        text.gsub(Label.reference_pattern) do |match|
          yield match, $~[:label_id].to_i, $~[:label_name]
        end
      end

      def call
        replace_text_nodes_matching(Label.reference_pattern) do |content|
          label_link_filter(content)
        end
      end

      def label_link_filter(text)
        project = context[:project]

        self.class.references_in(text) do |match, id, name|
          params = label_params(id, name)

          if label = project.labels.find_by(params)
            push_result(:label, label)

            url = url_for_label(project, label)
            klass = reference_class(:label)
            data = data_attribute(project.id)

            %(<a href="#{url}" #{data}
                 class="#{klass}">#{render_colored_label(label)}</a>)
          else
            match
          end
        end
      end

      def url_for_label(project, label)
        h = Rails.application.routes.url_helpers
        h.namespace_project_issues_path(project.namespace, project,
                                        label_name: label.name,
                                        only_path: context[:only_path])
      end

      def render_colored_label(label)
        LabelsHelper.render_colored_label(label)
      end

      def label_params(id, name)
        if name
          { name: name.tr('"', '') }
        else
          { id: id }
        end
      end
    end
  end
end
