module API
  class Users < Grape::API
    before { authenticate! }

    resource :users do
      get do
        @users = User.all
        @users = @users.active if params[:active].present?
        @users = @users.search(params[:search]) if params[:search].present?
        @users = paginate @users

        if current_user.is_admin?
          present @users, with: Entities::UserFull
        else
          present @users, with: Entities::UserBasic
        end
      end

      get ":id" do
        @user = User.find(params[:id])

        if current_user.is_admin?
          present @user, with: Entities::UserFull
        else
          present @user, with: Entities::UserBasic
        end
      end

      post do
        authenticated_as_admin!
        required_attributes! [:email, :password, :name, :username]
        attrs = attributes_for_keys [:email, :name, :password, :skype, :linkedin, :twitter, :projects_limit, :username, :bio, :can_create_group, :admin, :confirm]
        admin = attrs.delete(:admin)
        confirm = !(attrs.delete(:confirm) =~ (/(false|f|no|0)$/i))
        user = User.build_user(attrs)
        user.admin = admin unless admin.nil?
        user.skip_confirmation! unless confirm

        identity_attrs = attributes_for_keys [:provider, :extern_uid]
        if identity_attrs.any?
          user.identities.build(identity_attrs)
        end

        if user.save
          present user, with: Entities::UserFull
        else
          conflict!('Email has already been taken') if User.
              where(email: user.email).
              count > 0

          conflict!('Username has already been taken') if User.
              where(username: user.username).
              count > 0

          render_validation_error!(user)
        end
      end

      put ":id" do
        authenticated_as_admin!

        attrs = attributes_for_keys [:email, :name, :password, :skype, :linkedin, :twitter, :website_url, :projects_limit, :username, :bio, :can_create_group, :admin]
        user = User.find(params[:id])
        not_found!('User') unless user

        admin = attrs.delete(:admin)
        user.admin = admin unless admin.nil?

        conflict!('Email has already been taken') if attrs[:email] &&
            User.where(email: attrs[:email]).
                where.not(id: user.id).count > 0

        conflict!('Username has already been taken') if attrs[:username] &&
            User.where(username: attrs[:username]).
                where.not(id: user.id).count > 0

        if user.update_attributes(attrs)
          present user, with: Entities::UserFull
        else
          render_validation_error!(user)
        end
      end

      post ":id/keys" do
        authenticated_as_admin!
        required_attributes! [:title, :key]

        user = User.find(params[:id])
        attrs = attributes_for_keys [:title, :key]
        key = user.keys.new attrs
        if key.save
          present key, with: Entities::SSHKey
        else
          render_validation_error!(key)
        end
      end

      get ':uid/keys' do
        authenticated_as_admin!
        user = User.find_by(id: params[:uid])
        not_found!('User') unless user

        present user.keys, with: Entities::SSHKey
      end

      delete ':uid/keys/:id' do
        authenticated_as_admin!
        user = User.find_by(id: params[:uid])
        not_found!('User') unless user

        begin
          key = user.keys.find params[:id]
          key.destroy
        rescue ActiveRecord::RecordNotFound
          not_found!('Key')
        end
      end

      post ":id/emails" do
        authenticated_as_admin!
        required_attributes! [:email]

        user = User.find(params[:id])
        attrs = attributes_for_keys [:email]
        email = user.emails.new attrs
        if email.save
          NotificationService.new.new_email(email)
          present email, with: Entities::Email
        else
          render_validation_error!(email)
        end
      end

      get ':uid/emails' do
        authenticated_as_admin!
        user = User.find_by(id: params[:uid])
        not_found!('User') unless user

        present user.emails, with: Entities::Email
      end

      delete ':uid/emails/:id' do
        authenticated_as_admin!
        user = User.find_by(id: params[:uid])
        not_found!('User') unless user

        begin
          email = user.emails.find params[:id]
          email.destroy

          user.update_secondary_emails!
        rescue ActiveRecord::RecordNotFound
          not_found!('Email')
        end
      end

      delete ":id" do
        authenticated_as_admin!
        user = User.find_by(id: params[:id])

        if user
          DeleteUserService.new(current_user).execute(user)
        else
          not_found!('User')
        end
      end

      put ':id/block' do
        authenticated_as_admin!
        user = User.find_by(id: params[:id])

        if user
          user.block
        else
          not_found!('User')
        end
      end

      put ':id/unblock' do
        authenticated_as_admin!
        user = User.find_by(id: params[:id])

        if user
          user.activate
        else
          not_found!('User')
        end
      end
    end

    resource :user do
      get do
        present @current_user, with: Entities::UserLogin
      end

      get "keys" do
        present current_user.keys, with: Entities::SSHKey
      end

      get "keys/:id" do
        key = current_user.keys.find params[:id]
        present key, with: Entities::SSHKey
      end

      post "keys" do
        required_attributes! [:title, :key]

        attrs = attributes_for_keys [:title, :key]
        key = current_user.keys.new attrs
        if key.save
          present key, with: Entities::SSHKey
        else
          render_validation_error!(key)
        end
      end

      delete "keys/:id" do
        begin
          key = current_user.keys.find params[:id]
          key.destroy
        rescue
        end
      end

      get "emails" do
        present current_user.emails, with: Entities::Email
      end

      get "emails/:id" do
        email = current_user.emails.find params[:id]
        present email, with: Entities::Email
      end

      post "emails" do
        required_attributes! [:email]

        attrs = attributes_for_keys [:email]
        email = current_user.emails.new attrs
        if email.save
          NotificationService.new.new_email(email)
          present email, with: Entities::Email
        else
          render_validation_error!(email)
        end
      end

      delete "emails/:id" do
        begin
          email = current_user.emails.find params[:id]
          email.destroy

          current_user.update_secondary_emails!
        rescue
        end
      end
    end
  end
end
