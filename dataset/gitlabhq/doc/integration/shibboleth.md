# Shibboleth OmniAuth Provider

This documentation is for enabling shibboleth with gitlab-omnibus package.

In order to enable Shibboleth support in gitlab we need to use Apache instead of Nginx (It may be possible to use Nginx, however I did not found way to easily configure Nginx that is bundled in gitlab-omnibus package). Apache uses mod_shib2 module for shibboleth authentication and can pass attributes as headers to omniauth-shibboleth provider.


To enable the Shibboleth OmniAuth provider you must:

1. Configure Apache shibboleth module. Installation and configuration of module it self is out of scope of this document.
Check https://wiki.shibboleth.net/ for more info.

1. You can find Apache config in gitlab-recipes (https://github.com/gitlabhq/gitlab-recipes/blob/master/web-server/apache/gitlab-ssl.conf)

Following changes are needed to enable shibboleth:

protect omniauth-shibboleth callback URL:
```
  <Location /users/auth/shibboleth/callback>
    AuthType shibboleth
    ShibRequestSetting requireSession 1
    ShibUseHeaders On
    require valid-user
  </Location>

  Alias /shibboleth-sp /usr/share/shibboleth
  <Location /shibboleth-sp>
    Satisfy any
  </Location>

  <Location /Shibboleth.sso>
    SetHandler shib
  </Location>
```
exclude shibboleth URLs from rewriting, add "RewriteCond %{REQUEST_URI} !/Shibboleth.sso" and "RewriteCond %{REQUEST_URI} !/shibboleth-sp", config should look like this:
```
  # Apache equivalent of Nginx try files
  RewriteEngine on
  RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_URI} !/Shibboleth.sso
  RewriteCond %{REQUEST_URI} !/shibboleth-sp
  RewriteRule .* http://127.0.0.1:8080%{REQUEST_URI} [P,QSA]
  RequestHeader set X_FORWARDED_PROTO 'https'
```

1.  Edit /etc/gitlab/gitlab.rb configuration file, your shibboleth attributes should be in form of "HTTP_ATTRIBUTE" and you should addjust them to your need and environment. Add any other configuration you need.

File should look like this:
```
external_url 'https://gitlab.example.com'
gitlab_rails['internal_api_url'] = 'https://gitlab.example.com'

# disable Nginx
nginx['enable'] = false

gitlab_rails['omniauth_allow_single_sign_on'] = true
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_providers'] = [
  {
    "name" => 'shibboleth',
        "args" => {
        "shib_session_id_field" => "HTTP_SHIB_SESSION_ID",
        "shib_application_id_field" => "HTTP_SHIB_APPLICATION_ID",
        "uid_field" => 'HTTP_EPPN',
        "name_field" => 'HTTP_CN',
        "info_fields" => { "email" => 'HTTP_MAIL'}
        }
  }
]

```
1. Save changes and reconfigure gitlab:
```
sudo gitlab-ctl reconfigure
```

On the sign in page there should now be a "Sign in with: Shibboleth" icon below the regular sign in form. Click the icon to begin the authentication process. You will be redirected to IdP server (Depends on your Shibboleth module configuration). If everything goes well the user will be returned to GitLab and will be signed in.
