module GitlabRoutingHelper
  def project_path(project, *args)
    namespace_project_path(project.namespace, project, *args)
  end

  def activity_project_path(project, *args)
    activity_namespace_project_path(project.namespace, project, *args)
  end

  def edit_project_path(project, *args)
    edit_namespace_project_path(project.namespace, project, *args)
  end

  def issue_path(entity, *args)
    namespace_project_issue_path(entity.project.namespace, entity.project, entity, *args)
  end

  def merge_request_path(entity, *args)
    namespace_project_merge_request_path(entity.project.namespace, entity.project, entity, *args)
  end

  def milestone_path(entity, *args)
    namespace_project_milestone_path(entity.project.namespace, entity.project, entity, *args)
  end

  def project_url(project, *args)
    namespace_project_url(project.namespace, project, *args)
  end

  def edit_project_url(project, *args)
    edit_namespace_project_url(project.namespace, project, *args)
  end

  def issue_url(entity, *args)
    namespace_project_issue_url(entity.project.namespace, entity.project, entity, *args)
  end

  def merge_request_url(entity, *args)
    namespace_project_merge_request_url(entity.project.namespace, entity.project, entity, *args)
  end

  def project_snippet_url(entity, *args)
    namespace_project_snippet_url(entity.project.namespace, entity.project, entity, *args)
  end

  def toggle_subscription_path(entity, *args)
    if entity.is_a?(Issue)
      toggle_subscription_namespace_project_issue_path(entity.project.namespace, entity.project, entity)
    else
      toggle_subscription_namespace_project_merge_request_path(entity.project.namespace, entity.project, entity)
    end
  end
end
