require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/slice"

module ActionDispatch::Routing
  class RouteSet #:nodoc:
    def finalize_with_devise!
      result = finalize_without_devise!

      @devise_finalized ||= begin
        if Devise.router_name.nil? && defined?(@devise_finalized) && self != Rails.application.try(:routes)
          warn "[DEVISE] We have detected that you are using devise_for inside engine routes. " \
            "In this case, you probably want to set Devise.router_name = MOUNT_POINT, where "   \
            "MOUNT_POINT is a symbol representing where this engine will be mounted at. For "   \
            "now Devise will default the mount point to :main_app. You can explicitly set it"   \
            " to :main_app as well in case you want to keep the current behavior."
        end

        Devise.configure_warden!
        Devise.regenerate_helpers!
        true
      end

      result
    end
    alias_method_chain :finalize!, :devise
  end

  class Mapper
    def devise_for(*resources)
      @devise_finalized = false
      raise_no_secret_key unless Devise.secret_key
      options = resources.extract_options!

      options[:as]          ||= @scope[:as]     if @scope[:as].present?
      options[:module]      ||= @scope[:module] if @scope[:module].present?
      options[:path_prefix] ||= @scope[:path]   if @scope[:path].present?
      options[:path_names]    = (@scope[:path_names] || {}).merge(options[:path_names] || {})
      options[:constraints]   = (@scope[:constraints] || {}).merge(options[:constraints] || {})
      options[:defaults]      = (@scope[:defaults] || {}).merge(options[:defaults] || {})
      options[:options]       = @scope[:options] || {}
      options[:options][:format] = false if options[:format] == false

      resources.map!(&:to_sym)

      resources.each do |resource|
        mapping = Devise.add_mapping(resource, options)

        begin
          raise_no_devise_method_error!(mapping.class_name) unless mapping.to.respond_to?(:devise)
        rescue NameError => e
          raise unless mapping.class_name == resource.to_s.classify
          warn "[WARNING] You provided devise_for #{resource.inspect} but there is " \
            "no model #{mapping.class_name} defined in your application"
          next
        rescue NoMethodError => e
          raise unless e.message.include?("undefined method `devise'")
          raise_no_devise_method_error!(mapping.class_name)
        end

        if options[:controllers] && options[:controllers][:omniauth_callbacks]
          unless mapping.omniauthable?
            raise ArgumentError, "Mapping omniauth_callbacks on a resource that is not omniauthable\n" \
              "Please add `devise :omniauthable` to the `#{mapping.class_name}` model"
          end
        end

        routes = mapping.used_routes

        devise_scope mapping.name do
          with_devise_exclusive_scope mapping.fullpath, mapping.name, options do
            #nodyna <send-2752> <SD COMPLEX (array)>
            routes.each { |mod| send("devise_#{mod}", mapping, mapping.controllers) }
          end
        end
      end
    end

    def authenticate(scope=nil, block=nil)
      constraints_for(:authenticate!, scope, block) do
        yield
      end
    end

    def authenticated(scope=nil, block=nil)
      constraints_for(:authenticate?, scope, block) do
        yield
      end
    end

    def unauthenticated(scope=nil)
      constraint = lambda do |request|
        not request.env["warden"].authenticate? scope: scope
      end

      constraints(constraint) do
        yield
      end
    end

    def devise_scope(scope)
      constraint = lambda do |request|
        request.env["devise.mapping"] = Devise.mappings[scope]
        true
      end

      constraints(constraint) do
        yield
      end
    end
    alias :as :devise_scope

    protected

      def devise_session(mapping, controllers) #:nodoc:
        resource :session, only: [], controller: controllers[:sessions], path: "" do
          get   :new,     path: mapping.path_names[:sign_in],  as: "new"
          post  :create,  path: mapping.path_names[:sign_in]
          match :destroy, path: mapping.path_names[:sign_out], as: "destroy", via: mapping.sign_out_via
        end
      end

      def devise_password(mapping, controllers) #:nodoc:
        resource :password, only: [:new, :create, :edit, :update],
          path: mapping.path_names[:password], controller: controllers[:passwords]
      end

      def devise_confirmation(mapping, controllers) #:nodoc:
        resource :confirmation, only: [:new, :create, :show],
          path: mapping.path_names[:confirmation], controller: controllers[:confirmations]
      end

      def devise_unlock(mapping, controllers) #:nodoc:
        if mapping.to.unlock_strategy_enabled?(:email)
          resource :unlock, only: [:new, :create, :show],
            path: mapping.path_names[:unlock], controller: controllers[:unlocks]
        end
      end

      def devise_registration(mapping, controllers) #:nodoc:
        path_names = {
          new: mapping.path_names[:sign_up],
          edit: mapping.path_names[:edit],
          cancel: mapping.path_names[:cancel]
        }

        options = {
          only: [:new, :create, :edit, :update, :destroy],
          path: mapping.path_names[:registration],
          path_names: path_names,
          controller: controllers[:registrations]
        }

        resource :registration, options do
          get :cancel
        end
      end

      def devise_omniauth_callback(mapping, controllers) #:nodoc:
        if mapping.fullpath =~ /:[a-zA-Z_]/
          raise <<-ERROR
Devise does not support scoping omniauth callbacks under a dynamic segment
and you have set #{mapping.fullpath.inspect}. You can work around by passing
`skip: :omniauth_callbacks` and manually defining the routes. Here is an example:

    match "/users/auth/:provider",
      constraints: { provider: /google|facebook/ },
      to: "devise/omniauth_callbacks#passthru",
      as: :omniauth_authorize,
      via: [:get, :post]

    match "/users/auth/:action/callback",
      constraints: { action: /google|facebook/ },
      to: "devise/omniauth_callbacks",
      as: :omniauth_callback,
      via: [:get, :post]
ERROR
        end

        path, @scope[:path] = @scope[:path], nil
        path_prefix = Devise.omniauth_path_prefix || "/#{mapping.fullpath}/auth".squeeze("/")

        set_omniauth_path_prefix!(path_prefix)

        providers = Regexp.union(mapping.to.omniauth_providers.map(&:to_s))

        match "#{path_prefix}/:provider",
          constraints: { provider: providers },
          to: "#{controllers[:omniauth_callbacks]}#passthru",
          as: :omniauth_authorize,
          via: [:get, :post]

        match "#{path_prefix}/:action/callback",
          constraints: { action: providers },
          to: "#{controllers[:omniauth_callbacks]}#:action",
          as: :omniauth_callback,
          via: [:get, :post]
      ensure
        @scope[:path] = path
      end

      def with_devise_exclusive_scope(new_path, new_as, options) #:nodoc:
        current_scope = @scope.dup

        exclusive = { as: new_as, path: new_path, module: nil }
        exclusive.merge!(options.slice(:constraints, :defaults, :options))

        exclusive.each_pair { |key, value| @scope[key] = value }
        yield
      ensure
        @scope = current_scope
      end

      def constraints_for(method_to_apply, scope=nil, block=nil)
        constraint = lambda do |request|
          #nodyna <send-2753> <SD MODERATE (change-prone variable)>
          request.env['warden'].send(method_to_apply, scope: scope) &&
            (block.nil? || block.call(request.env["warden"].user(scope)))
        end

        constraints(constraint) do
          yield
        end
      end

      def set_omniauth_path_prefix!(path_prefix) #:nodoc:
        if ::OmniAuth.config.path_prefix && ::OmniAuth.config.path_prefix != path_prefix
          raise "Wrong OmniAuth configuration. If you are getting this exception, it means that either:\n\n" \
            "1) You are manually setting OmniAuth.config.path_prefix and it doesn't match the Devise one\n" \
            "2) You are setting :omniauthable in more than one model\n" \
            "3) You changed your Devise routes/OmniAuth setting and haven't restarted your server"
        else
          ::OmniAuth.config.path_prefix = path_prefix
        end
      end

      def raise_no_secret_key #:nodoc:
        raise <<-ERROR
Devise.secret_key was not set. Please add the following to your Devise initializer:

  config.secret_key = '#{SecureRandom.hex(64)}'

Please ensure you restarted your application after installing Devise or setting the key.
ERROR
      end

      def raise_no_devise_method_error!(klass) #:nodoc:
        raise "#{klass} does not respond to 'devise' method. This usually means you haven't " \
          "loaded your ORM file or it's being loaded too late. To fix it, be sure to require 'devise/orm/YOUR_ORM' " \
          "inside 'config/initializers/devise.rb' or before your application definition in 'config/application.rb'"
      end
  end
end
