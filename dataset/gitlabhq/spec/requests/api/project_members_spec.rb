require 'spec_helper'

describe API::API, api: true  do
  include ApiHelpers
  let(:user) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:project) { create(:project, creator_id: user.id, namespace: user.namespace) }
  let(:project_member) { create(:project_member, user: user, project: project, access_level: ProjectMember::MASTER) }
  let(:project_member2) { create(:project_member, user: user3, project: project, access_level: ProjectMember::DEVELOPER) }

  describe "GET /projects/:id/members" do
    before { project_member }
    before { project_member2 }

    it "should return project team members" do
      get api("/projects/#{project.id}/members", user)
      expect(response.status).to eq(200)
      expect(json_response).to be_an Array
      expect(json_response.count).to eq(2)
      expect(json_response.map { |u| u['username'] }).to include user.username
    end

    it "finds team members with query string" do
      get api("/projects/#{project.id}/members", user), query: user.username
      expect(response.status).to eq(200)
      expect(json_response).to be_an Array
      expect(json_response.count).to eq(1)
      expect(json_response.first['username']).to eq(user.username)
    end

    it "should return a 404 error if id not found" do
      get api("/projects/9999/members", user)
      expect(response.status).to eq(404)
    end
  end

  describe "GET /projects/:id/members/:user_id" do
    before { project_member }

    it "should return project team member" do
      get api("/projects/#{project.id}/members/#{user.id}", user)
      expect(response.status).to eq(200)
      expect(json_response['username']).to eq(user.username)
      expect(json_response['access_level']).to eq(ProjectMember::MASTER)
    end

    it "should return a 404 error if user id not found" do
      get api("/projects/#{project.id}/members/1234", user)
      expect(response.status).to eq(404)
    end
  end

  describe "POST /projects/:id/members" do
    it "should add user to project team" do
      expect do
        post api("/projects/#{project.id}/members", user), user_id: user2.id, access_level: ProjectMember::DEVELOPER
      end.to change { ProjectMember.count }.by(1)

      expect(response.status).to eq(201)
      expect(json_response['username']).to eq(user2.username)
      expect(json_response['access_level']).to eq(ProjectMember::DEVELOPER)
    end

    it "should return a 201 status if user is already project member" do
      post api("/projects/#{project.id}/members", user),
           user_id: user2.id,
           access_level: ProjectMember::DEVELOPER
      expect do
        post api("/projects/#{project.id}/members", user), user_id: user2.id, access_level: ProjectMember::DEVELOPER
      end.not_to change { ProjectMember.count }

      expect(response.status).to eq(201)
      expect(json_response['username']).to eq(user2.username)
      expect(json_response['access_level']).to eq(ProjectMember::DEVELOPER)
    end

    it "should return a 400 error when user id is not given" do
      post api("/projects/#{project.id}/members", user), access_level: ProjectMember::MASTER
      expect(response.status).to eq(400)
    end

    it "should return a 400 error when access level is not given" do
      post api("/projects/#{project.id}/members", user), user_id: user2.id
      expect(response.status).to eq(400)
    end

    it "should return a 422 error when access level is not known" do
      post api("/projects/#{project.id}/members", user), user_id: user2.id, access_level: 1234
      expect(response.status).to eq(422)
    end
  end

  describe "PUT /projects/:id/members/:user_id" do
    before { project_member2 }

    it "should update project team member" do
      put api("/projects/#{project.id}/members/#{user3.id}", user), access_level: ProjectMember::MASTER
      expect(response.status).to eq(200)
      expect(json_response['username']).to eq(user3.username)
      expect(json_response['access_level']).to eq(ProjectMember::MASTER)
    end

    it "should return a 404 error if user_id is not found" do
      put api("/projects/#{project.id}/members/1234", user), access_level: ProjectMember::MASTER
      expect(response.status).to eq(404)
    end

    it "should return a 400 error when access level is not given" do
      put api("/projects/#{project.id}/members/#{user3.id}", user)
      expect(response.status).to eq(400)
    end

    it "should return a 422 error when access level is not known" do
      put api("/projects/#{project.id}/members/#{user3.id}", user), access_level: 123
      expect(response.status).to eq(422)
    end
  end

  describe "DELETE /projects/:id/members/:user_id" do
    before { project_member }
    before { project_member2 }

    it "should remove user from project team" do
      expect do
        delete api("/projects/#{project.id}/members/#{user3.id}", user)
      end.to change { ProjectMember.count }.by(-1)
    end

    it "should return 200 if team member is not part of a project" do
      delete api("/projects/#{project.id}/members/#{user3.id}", user)
      expect do
        delete api("/projects/#{project.id}/members/#{user3.id}", user)
      end.to_not change { ProjectMember.count }
    end

    it "should return 200 if team member already removed" do
      delete api("/projects/#{project.id}/members/#{user3.id}", user)
      delete api("/projects/#{project.id}/members/#{user3.id}", user)
      expect(response.status).to eq(200)
    end

    it "should return 200 OK when the user was not member" do
      expect do
        delete api("/projects/#{project.id}/members/1000000", user)
      end.to change { ProjectMember.count }.by(0)
      expect(response.status).to eq(200)
      expect(json_response['message']).to eq("Access revoked")
      expect(json_response['id']).to eq(1000000)
    end
  end
end
