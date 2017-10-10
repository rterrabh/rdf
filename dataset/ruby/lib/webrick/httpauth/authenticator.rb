
module WEBrick
  module HTTPAuth


    module Authenticator

      RequestField      = "Authorization" # :nodoc:
      ResponseField     = "WWW-Authenticate" # :nodoc:
      ResponseInfoField = "Authentication-Info" # :nodoc:
      AuthException     = HTTPStatus::Unauthorized # :nodoc:


      AuthScheme        = nil


      attr_reader :realm


      attr_reader :userdb


      attr_reader :logger

      private



      def check_init(config)
        [:UserDB, :Realm].each{|sym|
          unless config[sym]
            raise ArgumentError, "Argument #{sym.inspect} missing."
          end
        }
        @realm     = config[:Realm]
        @userdb    = config[:UserDB]
        @logger    = config[:Logger] || Log::new($stderr)
        @reload_db = config[:AutoReloadUserDB]
        @request_field   = self::class::RequestField
        @response_field  = self::class::ResponseField
        @resp_info_field = self::class::ResponseInfoField
        @auth_exception  = self::class::AuthException
        @auth_scheme     = self::class::AuthScheme
      end


      def check_scheme(req)
        unless credentials = req[@request_field]
          error("no credentials in the request.")
          return nil
        end
        unless match = /^#{@auth_scheme}\s+/i.match(credentials)
          error("invalid scheme in %s.", credentials)
          info("%s: %s", @request_field, credentials) if $DEBUG
          return nil
        end
        return match.post_match
      end

      def log(meth, fmt, *args)
        msg = format("%s %s: ", @auth_scheme, @realm)
        msg << fmt % args
        #nodyna <send-2231> <SD MODERATE (change-prone variables)>
        @logger.send(meth, msg)
      end

      def error(fmt, *args)
        if @logger.error?
          log(:error, fmt, *args)
        end
      end

      def info(fmt, *args)
        if @logger.info?
          log(:info, fmt, *args)
        end
      end

    end


    module ProxyAuthenticator
      RequestField  = "Proxy-Authorization" # :nodoc:
      ResponseField = "Proxy-Authenticate" # :nodoc:
      InfoField     = "Proxy-Authentication-Info" # :nodoc:
      AuthException = HTTPStatus::ProxyAuthenticationRequired # :nodoc:
    end
  end
end
