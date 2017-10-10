
require 'webrick/config'
require 'webrick/httpstatus'
require 'webrick/httpauth/authenticator'

module WEBrick
  module HTTPAuth


    class BasicAuth
      include Authenticator

      AuthScheme = "Basic" # :nodoc:


      def self.make_passwd(realm, user, pass)
        pass ||= ""
        pass.crypt(Utils::random_string(2))
      end

      attr_reader :realm, :userdb, :logger


      def initialize(config, default=Config::BasicAuth)
        check_init(config)
        @config = default.dup.update(config)
      end


      def authenticate(req, res)
        unless basic_credentials = check_scheme(req)
          challenge(req, res)
        end
        userid, password = basic_credentials.unpack("m*")[0].split(":", 2)
        password ||= ""
        if userid.empty?
          error("user id was not given.")
          challenge(req, res)
        end
        unless encpass = @userdb.get_passwd(@realm, userid, @reload_db)
          error("%s: the user is not allowed.", userid)
          challenge(req, res)
        end
        if password.crypt(encpass) != encpass
          error("%s: password unmatch.", userid)
          challenge(req, res)
        end
        info("%s: authentication succeeded.", userid)
        req.user = userid
      end


      def challenge(req, res)
        res[@response_field] = "#{@auth_scheme} realm=\"#{@realm}\""
        raise @auth_exception
      end
    end


    class ProxyBasicAuth < BasicAuth
      include ProxyAuthenticator
    end
  end
end
