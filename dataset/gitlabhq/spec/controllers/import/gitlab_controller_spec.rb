require 'spec_helper'
require_relative 'import_spec_helper'

describe Import::GitlabController do
  include ImportSpecHelper

  let(:user) { create(:user, gitlab_access_token: 'asd123') }

  before do
    sign_in(user)
    allow(controller).to receive(:gitlab_import_enabled?).and_return(true)
  end

  describe "GET callback" do
    it "updates access token" do
      token = "asdasd12345"
      allow_any_instance_of(Gitlab::GitlabImport::Client).
        to receive(:get_token).and_return(token)
      stub_omniauth_provider('gitlab')

      get :callback

      expect(user.reload.gitlab_access_token).to eq(token)
      expect(controller).to redirect_to(status_import_gitlab_url)
    end
  end

  describe "GET status" do
    before do
      @repo = OpenStruct.new(path: 'vim', path_with_namespace: 'asd/vim')
    end

    it "assigns variables" do
      @project = create(:project, import_type: 'gitlab', creator_id: user.id)
      stub_client(projects: [@repo])

      get :status

      expect(assigns(:already_added_projects)).to eq([@project])
      expect(assigns(:repos)).to eq([@repo])
    end

    it "does not show already added project" do
      @project = create(:project, import_type: 'gitlab', creator_id: user.id, import_source: 'asd/vim')
      stub_client(projects: [@repo])

      get :status

      expect(assigns(:already_added_projects)).to eq([@project])
      expect(assigns(:repos)).to eq([])
    end
  end

  describe "POST create" do
    let(:gitlab_username) { user.username }
    let(:gitlab_user) do
      { username: gitlab_username }.with_indifferent_access
    end
    let(:gitlab_repo) do
      {
        path: 'vim',
        path_with_namespace: "#{gitlab_username}/vim",
        owner: { name: gitlab_username },
        namespace: { path: gitlab_username }
      }.with_indifferent_access
    end

    before do
      stub_client(user: gitlab_user, project: gitlab_repo)
    end

    context "when the repository owner is the GitLab.com user" do
      context "when the GitLab.com user and GitLab server user's usernames match" do
        it "takes the current user's namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator).
            to receive(:new).with(gitlab_repo, user.namespace, user).
            and_return(double(execute: true))

          post :create, format: :js
        end
      end

      context "when the GitLab.com user and GitLab server user's usernames don't match" do
        let(:gitlab_username) { "someone_else" }

        it "takes the current user's namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator).
            to receive(:new).with(gitlab_repo, user.namespace, user).
            and_return(double(execute: true))

          post :create, format: :js
        end
      end
    end

    context "when the repository owner is not the GitLab.com user" do
      let(:other_username) { "someone_else" }

      before do
        gitlab_repo["namespace"]["path"] = other_username
      end

      context "when a namespace with the GitLab.com user's username already exists" do
        let!(:existing_namespace) { create(:namespace, name: other_username, owner: user) }

        context "when the namespace is owned by the GitLab server user" do
          it "takes the existing namespace" do
            expect(Gitlab::GitlabImport::ProjectCreator).
              to receive(:new).with(gitlab_repo, existing_namespace, user).
              and_return(double(execute: true))

            post :create, format: :js
          end
        end

        context "when the namespace is not owned by the GitLab server user" do
          before do
            existing_namespace.owner = create(:user)
            existing_namespace.save
          end

          it "doesn't create a project" do
            expect(Gitlab::GitlabImport::ProjectCreator).
              not_to receive(:new)

            post :create, format: :js
          end
        end
      end

      context "when a namespace with the GitLab.com user's username doesn't exist" do
        it "creates the namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator).
            to receive(:new).and_return(double(execute: true))

          post :create, format: :js

          expect(Namespace.where(name: other_username).first).not_to be_nil
        end

        it "takes the new namespace" do
          expect(Gitlab::GitlabImport::ProjectCreator).
            to receive(:new).with(gitlab_repo, an_instance_of(Group), user).
            and_return(double(execute: true))

          post :create, format: :js
        end
      end
    end
  end
end
