require 'spec_helper'

describe Gitlab::GitlabImport::ProjectCreator do
  let(:user) { create(:user, gitlab_access_token: "asdffg") }
  let(:repo) do
    {
      name: 'vim',
      path: 'vim',
      visibility_level: Gitlab::VisibilityLevel::PRIVATE,
      path_with_namespace: 'asd/vim',
      http_url_to_repo: "https://gitlab.com/asd/vim.git",
      owner: { name: "john" }
    }.with_indifferent_access
  end
  let(:namespace){ create(:group, owner: user) }

  before do
    namespace.add_owner(user)
  end

  it 'creates project' do
    allow_any_instance_of(Project).to receive(:add_import_job)

    project_creator = Gitlab::GitlabImport::ProjectCreator.new(repo, namespace, user)
    project = project_creator.execute

    expect(project.import_url).to eq("https://oauth2:asdffg@gitlab.com/asd/vim.git")
    expect(project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
  end
end
