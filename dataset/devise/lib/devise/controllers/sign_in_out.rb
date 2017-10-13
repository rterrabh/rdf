module Devise
  module Controllers
    module SignInOut
      def signed_in?(scope=nil)
        [ scope || Devise.mappings.keys ].flatten.any? do |_scope|
          warden.authenticate?(scope: _scope)
        end
      end

      def sign_in(resource_or_scope, *args)
        options  = args.extract_options!
        scope    = Devise::Mapping.find_scope!(resource_or_scope)
        resource = args.last || resource_or_scope

        expire_data_after_sign_in!

        if options[:bypass]
          warden.session_serializer.store(resource, scope)
        elsif warden.user(scope) == resource && !options.delete(:force)
          true
        else
          warden.set_user(resource, options.merge!(scope: scope))
        end
      end

      def sign_out(resource_or_scope=nil)
        return sign_out_all_scopes unless resource_or_scope
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        user = warden.user(scope: scope, run_callbacks: false) # If there is no user

        warden.raw_session.inspect # Without this inspect here. The session does not clear.
        warden.logout(scope)
        warden.clear_strategies_cache!(scope: scope)
        #nodyna <instance_variable_set-2771> <IVS COMPLEX (change-prone variable)>
        instance_variable_set(:"@current_#{scope}", nil)

        !!user
      end

      def sign_out_all_scopes(lock=true)
        users = Devise.mappings.keys.map { |s| warden.user(scope: s, run_callbacks: false) }

        warden.logout
        expire_data_after_sign_out!
        warden.clear_strategies_cache!
        warden.lock! if lock

        users.any?
      end

      private

      def expire_data_after_sign_in!
        session.empty?
        session.keys.grep(/^devise\./).each { |k| session.delete(k) }
      end

      def expire_data_after_sign_out!
        session.empty?
        session.keys.grep(/^devise\./).each { |k| session.delete(k) }
      end
    end
  end
end
