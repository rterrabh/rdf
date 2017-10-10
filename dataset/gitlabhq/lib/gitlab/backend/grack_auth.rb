require_relative 'shell_env'

module Grack
  class Auth < Rack::Auth::Basic

    attr_accessor :user, :project, :env

    def call(env)
      @env = env
      @request = Rack::Request.new(env)
      @auth = Request.new(env)

      @gitlab_ci = false

      unless Gitlab.config.gitlab.relative_url_root.empty?
        @env['PATH_INFO'] = @request.path.sub(Gitlab.config.gitlab.relative_url_root,'')
      else
        @env['PATH_INFO'] = @request.path
      end

      @env['SCRIPT_NAME'] = ""

      auth!

      if project && authorized_request?
        if ENV['GITLAB_GRACK_AUTH_ONLY'] == '1'
          render_grack_auth_ok
        else
          @app.call(env)
        end
      elsif @user.nil? && !@gitlab_ci
        unauthorized
      else
        render_not_found
      end
    end

    private

    def auth!
      return unless @auth.provided?

      return bad_request unless @auth.basic?

      login, password = @auth.credentials

      if gitlab_ci_request?(login, password)
        @gitlab_ci = true
        return
      end

      @user = authenticate_user(login, password)

      if @user
        Gitlab::ShellEnv.set_env(@user)
        @env['REMOTE_USER'] = @auth.username
      end
    end

    def gitlab_ci_request?(login, password)
      if login == "gitlab-ci-token" && project && project.gitlab_ci?
        token = project.gitlab_ci_service.token

        if token.present? && token == password && git_cmd == 'git-upload-pack'
          return true
        end
      end

      false
    end

    def oauth_access_token_check(login, password)
      if login == "oauth2" && git_cmd == 'git-upload-pack' && password.present?
        token = Doorkeeper::AccessToken.by_token(password)
        token && token.accessible? && User.find_by(id: token.resource_owner_id)
      end
    end

    def authenticate_user(login, password)
      user = Gitlab::Auth.new.find(login, password)

      unless user
        user = oauth_access_token_check(login, password)
      end

      config = Gitlab.config.rack_attack.git_basic_auth

      if config.enabled
        if user
          Rack::Attack::Allow2Ban.reset(@request.ip, config)
        else
          banned = Rack::Attack::Allow2Ban.filter(@request.ip, config) do
            if config.ip_whitelist.include?(@request.ip)
              false
            else
              true
            end
          end

          if banned
            Rails.logger.info "IP #{@request.ip} failed to login " \
              "as #{login} but has been temporarily banned from Git auth"
          end
        end
      end

      user
    end

    def authorized_request?
      return true if @gitlab_ci

      case git_cmd
      when *Gitlab::GitAccess::DOWNLOAD_COMMANDS
        if user
          Gitlab::GitAccess.new(user, project).download_access_check.allowed?
        elsif project.public?
          true
        else
          false
        end
      when *Gitlab::GitAccess::PUSH_COMMANDS
        if user
          true
        else
          false
        end
      else
        false
      end
    end

    def git_cmd
      if @request.get?
        @request.params['service']
      elsif @request.post?
        File.basename(@request.path)
      else
        nil
      end
    end

    def project
      return @project if defined?(@project)

      @project = project_by_path(@request.path_info)
    end

    def project_by_path(path)
      if m = /^([\w\.\/-]+)\.git/.match(path).to_a
        path_with_namespace = m.last
        path_with_namespace.gsub!(/\.wiki$/, '')

        path_with_namespace[0] = '' if path_with_namespace.start_with?('/')
        Project.find_with_namespace(path_with_namespace)
      end
    end

    def render_grack_auth_ok
      [200, { "Content-Type" => "application/json" }, [JSON.dump({ 'GL_ID' => Gitlab::ShellEnv.gl_id(@user) })]]
    end

    def render_not_found
      [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
    end
  end
end
