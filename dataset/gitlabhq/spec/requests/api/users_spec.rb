require 'spec_helper'

describe API::API, api: true  do
  include ApiHelpers

  let(:user)  { create(:user) }
  let(:admin) { create(:admin) }
  let(:key)   { create(:key, user: user) }
  let(:email)   { create(:email, user: user) }

  describe "GET /users" do
    context "when unauthenticated" do
      it "should return authentication error" do
        get api("/users")
        expect(response.status).to eq(401)
      end
    end

    context "when authenticated" do
      it "should return an array of users" do
        get api("/users", user)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        username = user.username
        expect(json_response.detect do |user|
          user['username'] == username
        end['username']).to eq(username)
      end
    end

    context "when admin" do
      it "should return an array of users" do
        get api("/users", admin)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.first.keys).to include 'email'
        expect(json_response.first.keys).to include 'identities'
        expect(json_response.first.keys).to include 'can_create_project'
        expect(json_response.first.keys).to include 'two_factor_enabled'
      end
    end
  end

  describe "GET /users/:id" do
    it "should return a user by id" do
      get api("/users/#{user.id}", user)
      expect(response.status).to eq(200)
      expect(json_response['username']).to eq(user.username)
    end

    it "should return a 401 if unauthenticated" do
      get api("/users/9998")
      expect(response.status).to eq(401)
    end

    it "should return a 404 error if user id not found" do
      get api("/users/9999", user)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end
  end

  describe "POST /users" do
    before{ admin }

    it "should create user" do
      expect do
        post api("/users", admin), attributes_for(:user, projects_limit: 3)
      end.to change { User.count }.by(1)
    end

    it "should create user with correct attributes" do
      post api('/users', admin), attributes_for(:user, admin: true, can_create_group: true)
      expect(response.status).to eq(201)
      user_id = json_response['id']
      new_user = User.find(user_id)
      expect(new_user).not_to eq(nil)
      expect(new_user.admin).to eq(true)
      expect(new_user.can_create_group).to eq(true)
    end

    it "should create non-admin user" do
      post api('/users', admin), attributes_for(:user, admin: false, can_create_group: false)
      expect(response.status).to eq(201)
      user_id = json_response['id']
      new_user = User.find(user_id)
      expect(new_user).not_to eq(nil)
      expect(new_user.admin).to eq(false)
      expect(new_user.can_create_group).to eq(false)
    end

    it "should create non-admin users by default" do
      post api('/users', admin), attributes_for(:user)
      expect(response.status).to eq(201)
      user_id = json_response['id']
      new_user = User.find(user_id)
      expect(new_user).not_to eq(nil)
      expect(new_user.admin).to eq(false)
    end

    it "should return 201 Created on success" do
      post api("/users", admin), attributes_for(:user, projects_limit: 3)
      expect(response.status).to eq(201)
    end

    it "should not create user with invalid email" do
      post api('/users', admin),
        email: 'invalid email',
        password: 'password',
        name: 'test'
      expect(response.status).to eq(400)
    end

    it 'should return 400 error if name not given' do
      post api('/users', admin), attributes_for(:user).except(:name)
      expect(response.status).to eq(400)
    end

    it 'should return 400 error if password not given' do
      post api('/users', admin), attributes_for(:user).except(:password)
      expect(response.status).to eq(400)
    end

    it 'should return 400 error if email not given' do
      post api('/users', admin), attributes_for(:user).except(:email)
      expect(response.status).to eq(400)
    end

    it 'should return 400 error if username not given' do
      post api('/users', admin), attributes_for(:user).except(:username)
      expect(response.status).to eq(400)
    end

    it 'should return 400 error if user does not validate' do
      post api('/users', admin),
        password: 'pass',
        email: 'test@example.com',
        username: 'test!',
        name: 'test',
        bio: 'g' * 256,
        projects_limit: -1
      expect(response.status).to eq(400)
      expect(json_response['message']['password']).
        to eq(['is too short (minimum is 8 characters)'])
      expect(json_response['message']['bio']).
        to eq(['is too long (maximum is 255 characters)'])
      expect(json_response['message']['projects_limit']).
        to eq(['must be greater than or equal to 0'])
      expect(json_response['message']['username']).
        to eq([Gitlab::Regex.send(:namespace_regex_message)])
    end

    it "shouldn't available for non admin users" do
      post api("/users", user), attributes_for(:user)
      expect(response.status).to eq(403)
    end

    context 'with existing user' do
      before do
        post api('/users', admin),
          email: 'test@example.com',
          password: 'password',
          username: 'test',
          name: 'foo'
      end

      it 'should return 409 conflict error if user with same email exists' do
        expect do
          post api('/users', admin),
            name: 'foo',
            email: 'test@example.com',
            password: 'password',
            username: 'foo'
        end.to change { User.count }.by(0)
        expect(response.status).to eq(409)
        expect(json_response['message']).to eq('Email has already been taken')
      end

      it 'should return 409 conflict error if same username exists' do
        expect do
          post api('/users', admin),
            name: 'foo',
            email: 'foo@example.com',
            password: 'password',
            username: 'test'
        end.to change { User.count }.by(0)
        expect(response.status).to eq(409)
        expect(json_response['message']).to eq('Username has already been taken')
      end
    end
  end

  describe "GET /users/sign_up" do

    it "should redirect to sign in page" do
      get "/users/sign_up"
      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "PUT /users/:id" do
    let!(:admin_user) { create(:admin) }

    before { admin }

    it "should update user with new bio" do
      put api("/users/#{user.id}", admin), { bio: 'new test bio' }
      expect(response.status).to eq(200)
      expect(json_response['bio']).to eq('new test bio')
      expect(user.reload.bio).to eq('new test bio')
    end

    it 'should update user with his own email' do
      put api("/users/#{user.id}", admin), email: user.email
      expect(response.status).to eq(200)
      expect(json_response['email']).to eq(user.email)
      expect(user.reload.email).to eq(user.email)
    end

    it 'should update user with his own username' do
      put api("/users/#{user.id}", admin), username: user.username
      expect(response.status).to eq(200)
      expect(json_response['username']).to eq(user.username)
      expect(user.reload.username).to eq(user.username)
    end

    it "should update admin status" do
      put api("/users/#{user.id}", admin), { admin: true }
      expect(response.status).to eq(200)
      expect(json_response['is_admin']).to eq(true)
      expect(user.reload.admin).to eq(true)
    end

    it "should not update admin status" do
      put api("/users/#{admin_user.id}", admin), { can_create_group: false }
      expect(response.status).to eq(200)
      expect(json_response['is_admin']).to eq(true)
      expect(admin_user.reload.admin).to eq(true)
      expect(admin_user.can_create_group).to eq(false)
    end

    it "should not allow invalid update" do
      put api("/users/#{user.id}", admin), { email: 'invalid email' }
      expect(response.status).to eq(400)
      expect(user.reload.email).not_to eq('invalid email')
    end

    it "shouldn't available for non admin users" do
      put api("/users/#{user.id}", user), attributes_for(:user)
      expect(response.status).to eq(403)
    end

    it "should return 404 for non-existing user" do
      put api("/users/999999", admin), { bio: 'update should fail' }
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end

    it 'should return 400 error if user does not validate' do
      put api("/users/#{user.id}", admin),
        password: 'pass',
        email: 'test@example.com',
        username: 'test!',
        name: 'test',
        bio: 'g' * 256,
        projects_limit: -1
      expect(response.status).to eq(400)
      expect(json_response['message']['password']).
        to eq(['is too short (minimum is 8 characters)'])
      expect(json_response['message']['bio']).
        to eq(['is too long (maximum is 255 characters)'])
      expect(json_response['message']['projects_limit']).
        to eq(['must be greater than or equal to 0'])
      expect(json_response['message']['username']).
        to eq([Gitlab::Regex.send(:namespace_regex_message)])
    end

    context "with existing user" do
      before do
        post api("/users", admin), { email: 'test@example.com', password: 'password', username: 'test', name: 'test' }
        post api("/users", admin), { email: 'foo@bar.com', password: 'password', username: 'john', name: 'john' }
        @user = User.all.last
      end

      it 'should return 409 conflict error if email address exists' do
        put api("/users/#{@user.id}", admin), email: 'test@example.com'
        expect(response.status).to eq(409)
        expect(@user.reload.email).to eq(@user.email)
      end

      it 'should return 409 conflict error if username taken' do
        @user_id = User.all.last.id
        put api("/users/#{@user.id}", admin), username: 'test'
        expect(response.status).to eq(409)
        expect(@user.reload.username).to eq(@user.username)
      end
    end
  end

  describe "POST /users/:id/keys" do
    before { admin }

    it "should not create invalid ssh key" do
      post api("/users/#{user.id}/keys", admin), { title: "invalid key" }
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "key" not given')
    end

    it 'should not create key without title' do
      post api("/users/#{user.id}/keys", admin), key: 'some key'
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "title" not given')
    end

    it "should create ssh key" do
      key_attrs = attributes_for :key
      expect do
        post api("/users/#{user.id}/keys", admin), key_attrs
      end.to change{ user.keys.count }.by(1)
    end
  end

  describe 'GET /user/:uid/keys' do
    before { admin }

    context 'when unauthenticated' do
      it 'should return authentication error' do
        get api("/users/#{user.id}/keys")
        expect(response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      it 'should return 404 for non-existing user' do
        get api('/users/999999/keys', admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'should return array of ssh keys' do
        user.keys << key
        user.save
        get api("/users/#{user.id}/keys", admin)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.first['title']).to eq(key.title)
      end
    end
  end

  describe 'DELETE /user/:uid/keys/:id' do
    before { admin }

    context 'when unauthenticated' do
      it 'should return authentication error' do
        delete api("/users/#{user.id}/keys/42")
        expect(response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      it 'should delete existing key' do
        user.keys << key
        user.save
        expect do
          delete api("/users/#{user.id}/keys/#{key.id}", admin)
        end.to change { user.keys.count }.by(-1)
        expect(response.status).to eq(200)
      end

      it 'should return 404 error if user not found' do
        user.keys << key
        user.save
        delete api("/users/999999/keys/#{key.id}", admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'should return 404 error if key not foud' do
        delete api("/users/#{user.id}/keys/42", admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 Key Not Found')
      end
    end
  end

  describe "POST /users/:id/emails" do
    before { admin }

    it "should not create invalid email" do
      post api("/users/#{user.id}/emails", admin), {}
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "email" not given')
    end

    it "should create email" do
      email_attrs = attributes_for :email
      expect do
        post api("/users/#{user.id}/emails", admin), email_attrs
      end.to change{ user.emails.count }.by(1)
    end
  end

  describe 'GET /user/:uid/emails' do
    before { admin }

    context 'when unauthenticated' do
      it 'should return authentication error' do
        get api("/users/#{user.id}/emails")
        expect(response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      it 'should return 404 for non-existing user' do
        get api('/users/999999/emails', admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'should return array of emails' do
        user.emails << email
        user.save
        get api("/users/#{user.id}/emails", admin)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.first['email']).to eq(email.email)
      end
    end
  end

  describe 'DELETE /user/:uid/emails/:id' do
    before { admin }

    context 'when unauthenticated' do
      it 'should return authentication error' do
        delete api("/users/#{user.id}/emails/42")
        expect(response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      it 'should delete existing email' do
        user.emails << email
        user.save
        expect do
          delete api("/users/#{user.id}/emails/#{email.id}", admin)
        end.to change { user.emails.count }.by(-1)
        expect(response.status).to eq(200)
      end

      it 'should return 404 error if user not found' do
        user.emails << email
        user.save
        delete api("/users/999999/emails/#{email.id}", admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'should return 404 error if email not foud' do
        delete api("/users/#{user.id}/emails/42", admin)
        expect(response.status).to eq(404)
        expect(json_response['message']).to eq('404 Email Not Found')
      end
    end
  end

  describe "DELETE /users/:id" do
    before { admin }

    it "should delete user" do
      delete api("/users/#{user.id}", admin)
      expect(response.status).to eq(200)
      expect { User.find(user.id) }.to raise_error ActiveRecord::RecordNotFound
      expect(json_response['email']).to eq(user.email)
    end

    it "should not delete for unauthenticated user" do
      delete api("/users/#{user.id}")
      expect(response.status).to eq(401)
    end

    it "shouldn't available for non admin users" do
      delete api("/users/#{user.id}", user)
      expect(response.status).to eq(403)
    end

    it "should return 404 for non-existing user" do
      delete api("/users/999999", admin)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 User Not Found')
    end
  end

  describe "GET /user" do
    it "should return current user" do
      get api("/user", user)
      expect(response.status).to eq(200)
      expect(json_response['email']).to eq(user.email)
      expect(json_response['is_admin']).to eq(user.is_admin?)
      expect(json_response['can_create_project']).to eq(user.can_create_project?)
      expect(json_response['can_create_group']).to eq(user.can_create_group?)
      expect(json_response['projects_limit']).to eq(user.projects_limit)
    end

    it "should return 401 error if user is unauthenticated" do
      get api("/user")
      expect(response.status).to eq(401)
    end
  end

  describe "GET /user/keys" do
    context "when unauthenticated" do
      it "should return authentication error" do
        get api("/user/keys")
        expect(response.status).to eq(401)
      end
    end

    context "when authenticated" do
      it "should return array of ssh keys" do
        user.keys << key
        user.save
        get api("/user/keys", user)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.first["title"]).to eq(key.title)
      end
    end
  end

  describe "GET /user/keys/:id" do
    it "should return single key" do
      user.keys << key
      user.save
      get api("/user/keys/#{key.id}", user)
      expect(response.status).to eq(200)
      expect(json_response["title"]).to eq(key.title)
    end

    it "should return 404 Not Found within invalid ID" do
      get api("/user/keys/42", user)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end

    it "should return 404 error if admin accesses user's ssh key" do
      user.keys << key
      user.save
      admin
      get api("/user/keys/#{key.id}", admin)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end
  end

  describe "POST /user/keys" do
    it "should create ssh key" do
      key_attrs = attributes_for :key
      expect do
        post api("/user/keys", user), key_attrs
      end.to change{ user.keys.count }.by(1)
      expect(response.status).to eq(201)
    end

    it "should return a 401 error if unauthorized" do
      post api("/user/keys"), title: 'some title', key: 'some key'
      expect(response.status).to eq(401)
    end

    it "should not create ssh key without key" do
      post api("/user/keys", user), title: 'title'
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "key" not given')
    end

    it 'should not create ssh key without title' do
      post api('/user/keys', user), key: 'some key'
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "title" not given')
    end

    it "should not create ssh key without title" do
      post api("/user/keys", user), key: "somekey"
      expect(response.status).to eq(400)
    end
  end

  describe "DELETE /user/keys/:id" do
    it "should delete existed key" do
      user.keys << key
      user.save
      expect do
        delete api("/user/keys/#{key.id}", user)
      end.to change{user.keys.count}.by(-1)
      expect(response.status).to eq(200)
    end

    it "should return success if key ID not found" do
      delete api("/user/keys/42", user)
      expect(response.status).to eq(200)
    end

    it "should return 401 error if unauthorized" do
      user.keys << key
      user.save
      delete api("/user/keys/#{key.id}")
      expect(response.status).to eq(401)
    end
  end

  describe "GET /user/emails" do
    context "when unauthenticated" do
      it "should return authentication error" do
        get api("/user/emails")
        expect(response.status).to eq(401)
      end
    end

    context "when authenticated" do
      it "should return array of emails" do
        user.emails << email
        user.save
        get api("/user/emails", user)
        expect(response.status).to eq(200)
        expect(json_response).to be_an Array
        expect(json_response.first["email"]).to eq(email.email)
      end
    end
  end

  describe "GET /user/emails/:id" do
    it "should return single email" do
      user.emails << email
      user.save
      get api("/user/emails/#{email.id}", user)
      expect(response.status).to eq(200)
      expect(json_response["email"]).to eq(email.email)
    end

    it "should return 404 Not Found within invalid ID" do
      get api("/user/emails/42", user)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end

    it "should return 404 error if admin accesses user's email" do
      user.emails << email
      user.save
      admin
      get api("/user/emails/#{email.id}", admin)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 Not found')
    end
  end

  describe "POST /user/emails" do
    it "should create email" do
      email_attrs = attributes_for :email
      expect do
        post api("/user/emails", user), email_attrs
      end.to change{ user.emails.count }.by(1)
      expect(response.status).to eq(201)
    end

    it "should return a 401 error if unauthorized" do
      post api("/user/emails"), email: 'some email'
      expect(response.status).to eq(401)
    end

    it "should not create email with invalid email" do
      post api("/user/emails", user), {}
      expect(response.status).to eq(400)
      expect(json_response['message']).to eq('400 (Bad request) "email" not given')
    end
  end

  describe "DELETE /user/emails/:id" do
    it "should delete existed email" do
      user.emails << email
      user.save
      expect do
        delete api("/user/emails/#{email.id}", user)
      end.to change{user.emails.count}.by(-1)
      expect(response.status).to eq(200)
    end

    it "should return success if email ID not found" do
      delete api("/user/emails/42", user)
      expect(response.status).to eq(200)
    end

    it "should return 401 error if unauthorized" do
      user.emails << email
      user.save
      delete api("/user/emails/#{email.id}")
      expect(response.status).to eq(401)
    end
  end

  describe 'PUT /user/:id/block' do
    before { admin }
    it 'should block existing user' do
      put api("/users/#{user.id}/block", admin)
      expect(response.status).to eq(200)
      expect(user.reload.state).to eq('blocked')
    end

    it 'should not be available for non admin users' do
      put api("/users/#{user.id}/block", user)
      expect(response.status).to eq(403)
      expect(user.reload.state).to eq('active')
    end

    it 'should return a 404 error if user id not found' do
      put api('/users/9999/block', admin)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 User Not Found')
    end
  end

  describe 'PUT /user/:id/unblock' do
    before { admin }
    it 'should unblock existing user' do
      put api("/users/#{user.id}/unblock", admin)
      expect(response.status).to eq(200)
      expect(user.reload.state).to eq('active')
    end

    it 'should unblock a blocked user' do
      put api("/users/#{user.id}/block", admin)
      expect(response.status).to eq(200)
      expect(user.reload.state).to eq('blocked')
      put api("/users/#{user.id}/unblock", admin)
      expect(response.status).to eq(200)
      expect(user.reload.state).to eq('active')
    end

    it 'should not be available for non admin users' do
      put api("/users/#{user.id}/unblock", user)
      expect(response.status).to eq(403)
      expect(user.reload.state).to eq('active')
    end

    it 'should return a 404 error if user id not found' do
      put api('/users/9999/block', admin)
      expect(response.status).to eq(404)
      expect(json_response['message']).to eq('404 User Not Found')
    end
  end
end
