# Projects::TransferService class
#
# Used for transfer project to another namespace
#
# Ex.
#   # Move projects to namespace with ID 17 by user
#   Projects::TransferService.new(project, user, namespace_id: 17).execute
#
module Projects
  class TransferService < BaseService
    include Gitlab::ShellAdapter
    class TransferError < StandardError; end

    def execute(new_namespace)
      if allowed_transfer?(current_user, project, new_namespace)
        transfer(project, new_namespace)
      else
        project.errors.add(:new_namespace, 'is invalid')
        false
      end
    rescue Projects::TransferService::TransferError => ex
      project.reload
      project.errors.add(:new_namespace, ex.message)
      false
    end

    def transfer(project, new_namespace)
      Project.transaction do
        old_path = project.path_with_namespace
        new_path = File.join(new_namespace.try(:path) || '', project.path)

        if Project.where(path: project.path, namespace_id: new_namespace.try(:id)).present?
          raise TransferError.new("Project with same path in target namespace already exists")
        end

        # Remove old satellite
        project.satellite.destroy

        # Apply new namespace id
        project.namespace = new_namespace
        project.save!

        # Notifications
        project.send_move_instructions

        # Move main repository
        unless gitlab_shell.mv_repository(old_path, new_path)
          raise TransferError.new('Cannot move project')
        end

        # Move wiki repo also if present
        gitlab_shell.mv_repository("#{old_path}.wiki", "#{new_path}.wiki")

        # Create a new satellite (reload project from DB)
        Project.find(project.id).ensure_satellite_exists

        # clear project cached events
        project.reset_events_cache

        true
      end
    end

    def allowed_transfer?(current_user, project, namespace)
      namespace &&
        can?(current_user, :change_namespace, project) &&
        namespace.id != project.namespace_id &&
        current_user.can?(:create_projects, namespace)
    end
  end
end
