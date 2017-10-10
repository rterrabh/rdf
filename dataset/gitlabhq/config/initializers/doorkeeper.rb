Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    session[:user_return_to] = request.fullpath
    current_user || redirect_to(new_user_session_url)
  end

  resource_owner_from_credentials do |routes|
    u = User.find_by(email: params[:username]) || User.find_by(username: params[:username])
    u if u && u.valid_password?(params[:password])
  end



  access_token_expires_in nil


  use_refresh_token

  force_ssl_in_redirect_uri false

  enable_application_owner confirmation: false

  default_scopes  :api


  access_token_methods :from_access_token_param, :from_bearer_authorization, :from_bearer_param

  native_redirect_uri nil#'urn:ietf:wg:oauth:2.0:oob'

  grant_flows %w(authorization_code password client_credentials)



end
