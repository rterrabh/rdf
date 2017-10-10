require_dependency 'email'
require_dependency 'enum'
require_dependency 'user_name_suggester'

class Users::OmniauthCallbacksController < ApplicationController

  BUILTIN_AUTH = [
    Auth::FacebookAuthenticator.new,
    Auth::GoogleOAuth2Authenticator.new,
    Auth::OpenIdAuthenticator.new("yahoo", "https://me.yahoo.com", trusted: true),
    Auth::GithubAuthenticator.new,
    Auth::TwitterAuthenticator.new
  ]

  skip_before_filter :redirect_to_login_if_required

  layout false

  def self.types
    @types ||= Enum.new(:facebook, :twitter, :google, :yahoo, :github, :persona, :cas)
  end

  skip_before_filter :check_xhr

  skip_before_filter :verify_authenticity_token, only: :complete

  def complete
    auth = request.env["omniauth.auth"]
    auth[:session] = session

    authenticator = self.class.find_authenticator(params[:provider])

    @auth_result = authenticator.after_authenticate(auth)

    if @auth_result.failed?
      flash[:error] = @auth_result.failed_reason.html_safe
      return render('failure')
    else
      @auth_result.authenticator_name = authenticator.name
      complete_response_data
      respond_to do |format|
        format.html
        format.json { render json: @auth_result.to_client_hash }
      end
    end
  end

  def failure
    flash[:error] = I18n.t("login.omniauth_error")
    render layout: 'no_ember'
  end


  def self.find_authenticator(name)
    BUILTIN_AUTH.each do |authenticator|
      if authenticator.name == name
        #nodyna <send-455> <SD COMPLEX (change-prone variables)>
        raise Discourse::InvalidAccess.new("provider is not enabled") unless SiteSetting.send("enable_#{name}_logins?")
        return authenticator
      end
    end

    Discourse.auth_providers.each do |provider|
      return provider.authenticator if provider.name == name
    end

    raise Discourse::InvalidAccess.new("provider is not found")
  end

  protected

  def complete_response_data
    if @auth_result.user
      user_found(@auth_result.user)
    elsif SiteSetting.invite_only?
      @auth_result.requires_invite = true
    else
      session[:authentication] = @auth_result.session_data
    end
  end

  def user_found(user)
    if !user.active && @auth_result.email_valid
      user.toggle(:active).save
    end

    if ScreenedIpAddress.should_block?(request.remote_ip)
      @auth_result.not_allowed_from_ip_address = true
    elsif ScreenedIpAddress.block_admin_login?(user, request.remote_ip)
      @auth_result.admin_not_allowed_from_ip_address = true
    elsif Guardian.new(user).can_access_forum? && user.active # log on any account that is active with forum access
      log_on_user(user)
      Invite.invalidate_for_email(user.email) # invite link can't be used to log in anymore
      session[:authentication] = nil # don't carry around old auth info, perhaps move elsewhere
      @auth_result.authenticated = true
    else
      if SiteSetting.must_approve_users? && !user.approved?
        @auth_result.awaiting_approval = true
      else
        @auth_result.awaiting_activation = true
      end
    end
  end

end
