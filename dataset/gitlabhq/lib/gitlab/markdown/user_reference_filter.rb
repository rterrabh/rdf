module Gitlab
  module Markdown
    class UserReferenceFilter < ReferenceFilter
      def self.references_in(text)
        text.gsub(User.reference_pattern) do |match|
          yield match, $~[:user]
        end
      end

      def call
        replace_text_nodes_matching(User.reference_pattern) do |content|
          user_link_filter(content)
        end
      end

      def user_link_filter(text)
        self.class.references_in(text) do |match, username|
          if username == 'all'
            link_to_all
          elsif namespace = Namespace.find_by(path: username)
            link_to_namespace(namespace) || match
          else
            match
          end
        end
      end

      private

      def urls
        Rails.application.routes.url_helpers
      end

      def link_class
        reference_class(:project_member)
      end

      def link_to_all
        project = context[:project]

        push_result(:user, *project.team.members.flatten)

        url = urls.namespace_project_url(project.namespace, project,
                                         only_path: context[:only_path])

        text = User.reference_prefix + 'all'
        %(<a href="#{url}" class="#{link_class}">#{text}</a>)
      end

      def link_to_namespace(namespace)
        if namespace.is_a?(Group)
          link_to_group(namespace.path, namespace)
        else
          link_to_user(namespace.path, namespace)
        end
      end

      def link_to_group(group, namespace)
        return unless user_can_reference_group?(namespace)

        push_result(:user, *namespace.users)

        url = urls.group_url(group, only_path: context[:only_path])
        data = data_attribute(namespace.id, :group)

        text = Group.reference_prefix + group
        %(<a href="#{url}" #{data} class="#{link_class}">#{text}</a>)
      end

      def link_to_user(user, namespace)
        push_result(:user, namespace.owner)

        url = urls.user_url(user, only_path: context[:only_path])
        data = data_attribute(namespace.owner_id, :user)

        text = User.reference_prefix + user
        %(<a href="#{url}" #{data} class="#{link_class}">#{text}</a>)
      end

      def user_can_reference_group?(group)
        Ability.abilities.allowed?(context[:current_user], :read_group, group)
      end
    end
  end
end
