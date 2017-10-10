
module WEBrick
  module HTTPAuth


    module UserDB


      attr_accessor :auth_type


      def make_passwd(realm, user, pass)
        @auth_type::make_passwd(realm, user, pass)
      end


      def set_passwd(realm, user, pass)
        self[user] = pass
      end


      def get_passwd(realm, user, reload_db=false)
        make_passwd(realm, user, self[user])
      end
    end
  end
end
