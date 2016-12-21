require 'spec_helper'

describe Projects::MilestonesController do
  let(:project) { create(:project) }
  let(:user)    { create(:user) }
  let(:milestone) { create(:milestone, project: project) }
  let(:issue) { create(:issue, project: project, milestone: milestone) }

  before do
    sign_in(user)
    project.team << [user, :master]
    controller.instance_variable_set(:@project, project)
  end

  describe "#destroy" do
    it "should remove milestone" do
      expect(issue.milestone_id).to eq(milestone.id)
      delete :destroy, namespace_id: project.namespace.id, project_id: project.id, id: milestone.id, format: :js
      expect(response).to be_success
      expect { Milestone.find(milestone.id) }.to raise_exception(ActiveRecord::RecordNotFound)
      issue.reload
      expect(issue.milestone_id).to eq(nil)
      # Check system note left for milestone removal
      last_note = project.issues.find(issue.id).notes[-1].note
      expect(last_note).to eq('Milestone removed')
    end
  end
end
