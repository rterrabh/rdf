require 'rails_helper'

feature 'Issue filtering by Milestone', feature: true do
  include Select2Helper

  let(:project)   { create(:project, :public) }
  let(:milestone) { create(:milestone, project: project) }

  scenario 'filters by no Milestone', js: true do
    create(:issue, project: project)
    create(:issue, project: project, milestone: milestone)

    visit_issues(project)
    filter_by_milestone(Milestone::None.title)

    expect(page).to have_css('.issue-title', count: 1)
  end

  scenario 'filters by a specific Milestone', js: true do
    create(:issue, project: project, milestone: milestone)
    create(:issue, project: project)

    visit_issues(project)
    filter_by_milestone(milestone.title)

    expect(page).to have_css('.issue-title', count: 1)
  end

  def visit_issues(project)
    visit namespace_project_issues_path(project.namespace, project)
  end

  def filter_by_milestone(title)
    select2(title, from: '#milestone_title')
  end
end
