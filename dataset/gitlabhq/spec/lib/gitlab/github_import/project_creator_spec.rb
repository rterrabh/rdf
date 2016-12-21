require 'spec_helper'

describe Gitlab::GithubImport::ProjectCreator do
  let(:user) { create(:user, github_access_token: "asdffg") }
  let(:repo) do
    OpenStruct.new(
      login: 'vim',
      name: 'vim',
      private: true,
      full_name: 'asd/vim',
      clone_url: "https://gitlab.com/asd/vim.git",
      owner: OpenStruct.new(login: "john")
    )
  end
  let(:namespace){ create(:group, owner: user) }

  before do
    namespace.add_owner(user)
  end

  it 'creates project' do
    allow_any_instance_of(Project).to receive(:add_import_job)

    project_creator = Gitlab::GithubImport::ProjectCreator.new(repo, namespace, user)
    project = project_creator.execute

    expect(project.import_url).to eq("https://asdffg@gitlab.com/asd/vim.git")
    expect(project.visibility_level).to eq(Gitlab::VisibilityLevel::PRIVATE)
  end
end
