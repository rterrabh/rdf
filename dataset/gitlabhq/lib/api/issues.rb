module API
  class Issues < Grape::API
    before { authenticate! }

    helpers do
      def filter_issues_state(issues, state)
        case state
        when 'opened' then issues.opened
        when 'closed' then issues.closed
        else issues
        end
      end

      def filter_issues_labels(issues, labels)
        issues.includes(:labels).where('labels.title' => labels.split(','))
      end

      def filter_issues_milestone(issues, milestone)
        issues.includes(:milestone).where('milestones.title' => milestone)
      end
    end

    resource :issues do
      get do
        issues = current_user.issues
        issues = filter_issues_state(issues, params[:state]) unless params[:state].nil?
        issues = filter_issues_labels(issues, params[:labels]) unless params[:labels].nil?
        issues.reorder(issuable_order_by => issuable_sort)
        present paginate(issues), with: Entities::Issue
      end
    end

    resource :projects do
      get ":id/issues" do
        issues = user_project.issues
        issues = filter_issues_state(issues, params[:state]) unless params[:state].nil?
        issues = filter_issues_labels(issues, params[:labels]) unless params[:labels].nil?
        issues = filter_by_iid(issues, params[:iid]) unless params[:iid].nil?

        unless params[:milestone].nil?
          issues = filter_issues_milestone(issues, params[:milestone])
        end

        issues.reorder(issuable_order_by => issuable_sort)
        present paginate(issues), with: Entities::Issue
      end

      get ":id/issues/:issue_id" do
        @issue = user_project.issues.find(params[:issue_id])
        present @issue, with: Entities::Issue
      end

      post ":id/issues" do
        required_attributes! [:title]
        attrs = attributes_for_keys [:title, :description, :assignee_id, :milestone_id]

        if (errors = validate_label_params(params)).any?
          render_api_error!({ labels: errors }, 400)
        end

        issue = ::Issues::CreateService.new(user_project, current_user, attrs).execute

        if issue.valid?
          if params[:labels].present?
            issue.add_labels_by_names(params[:labels].split(','))
          end

          present issue, with: Entities::Issue
        else
          render_validation_error!(issue)
        end
      end

      put ":id/issues/:issue_id" do
        issue = user_project.issues.find(params[:issue_id])
        authorize! :update_issue, issue
        attrs = attributes_for_keys [:title, :description, :assignee_id, :milestone_id, :state_event]

        if (errors = validate_label_params(params)).any?
          render_api_error!({ labels: errors }, 400)
        end

        issue = ::Issues::UpdateService.new(user_project, current_user, attrs).execute(issue)

        if issue.valid?
          if params[:labels] && can?(current_user, :admin_issue, user_project)
            issue.remove_labels
            issue.add_labels_by_names(params[:labels].split(','))
          end

          present issue, with: Entities::Issue
        else
          render_validation_error!(issue)
        end
      end

      delete ":id/issues/:issue_id" do
        not_allowed!
      end
    end
  end
end
