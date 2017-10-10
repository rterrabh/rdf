
require 'webrick/httpauth/basicauth'
require 'webrick/httpauth/digestauth'
require 'webrick/httpauth/htpasswd'
require 'webrick/httpauth/htdigest'
require 'webrick/httpauth/htgroup'

module WEBrick


  module HTTPAuth
    module_function

    def _basic_auth(req, res, realm, req_field, res_field, err_type,
                    block) # :nodoc:
      user = pass = nil
      if /^Basic\s+(.*)/o =~ req[req_field]
        userpass = $1
        user, pass = userpass.unpack("m*")[0].split(":", 2)
      end
      if block.call(user, pass)
        req.user = user
        return
      end
      res[res_field] = "Basic realm=\"#{realm}\""
      raise err_type
    end


    def basic_auth(req, res, realm, &block) # :yield: username, password
      _basic_auth(req, res, realm, "Authorization", "WWW-Authenticate",
                  HTTPStatus::Unauthorized, block)
    end


    def proxy_basic_auth(req, res, realm, &block) # :yield: username, password
      _basic_auth(req, res, realm, "Proxy-Authorization", "Proxy-Authenticate",
                  HTTPStatus::ProxyAuthenticationRequired, block)
    end
  end
end
