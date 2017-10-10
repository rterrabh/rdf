module Gitlab
  module Markdown
    module CrossProjectReference
      def project_from_ref(ref)
        return context[:project] unless ref

        other = Project.find_with_namespace(ref)
        return nil unless other && user_can_reference_project?(other)

        other
      end

      def user_can_reference_project?(project, user = context[:current_user])
        Ability.abilities.allowed?(user, :read_project, project)
      end
    end
  end
end
