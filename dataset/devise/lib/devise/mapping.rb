module Devise
  class Mapping #:nodoc:
    attr_reader :singular, :scoped_path, :path, :controllers, :path_names,
                :class_name, :sign_out_via, :format, :used_routes, :used_helpers,
                :failure_app, :router_name

    alias :name :singular

    def self.find_scope!(obj)
      case obj
      when String, Symbol
        return obj.to_sym
      when Class
        Devise.mappings.each_value { |m| return m.name if obj <= m.to }
      else
        Devise.mappings.each_value { |m| return m.name if obj.is_a?(m.to) }
      end

      raise "Could not find a valid mapping for #{obj.inspect}"
    end

    def self.find_by_path!(path, path_type=:fullpath)
      #nodyna <send-2754> <not yet classified>
      Devise.mappings.each_value { |m| return m if path.include?(m.send(path_type)) }
      raise "Could not find a valid mapping for path #{path.inspect}"
    end

    def initialize(name, options) #:nodoc:
      @scoped_path = options[:as] ? "#{options[:as]}/#{name}" : name.to_s
      @singular = (options[:singular] || @scoped_path.tr('/', '_').singularize).to_sym

      @class_name = (options[:class_name] || name.to_s.classify).to_s
      @klass = Devise.ref(@class_name)

      @path = (options[:path] || name).to_s
      @path_prefix = options[:path_prefix]

      @sign_out_via = options[:sign_out_via] || Devise.sign_out_via
      @format = options[:format]

      @router_name = options[:router_name]

      default_failure_app(options)
      default_controllers(options)
      default_path_names(options)
      default_used_route(options)
      default_used_helpers(options)
    end

    def modules
      @modules ||= to.respond_to?(:devise_modules) ? to.devise_modules : []
    end

    def to
      @klass.get
    end

    def strategies
      @strategies ||= STRATEGIES.values_at(*self.modules).compact.uniq.reverse
    end

    def no_input_strategies
      self.strategies & Devise::NO_INPUT
    end

    def routes
      @routes ||= ROUTES.values_at(*self.modules).compact.uniq
    end

    def authenticatable?
      @authenticatable ||= self.modules.any? { |m| m.to_s =~ /authenticatable/ }
    end

    def fullpath
      "/#{@path_prefix}/#{@path}".squeeze("/")
    end

    def self.add_module(m)
      #nodyna <class_eval-2755> <not yet classified>
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{m}?
          self.modules.include?(:#{m})
        end
      METHOD
    end

    private

    def default_failure_app(options)
      @failure_app = options[:failure_app] || Devise::FailureApp
      if @failure_app.is_a?(String)
        ref = Devise.ref(@failure_app)
        @failure_app = lambda { |env| ref.get.call(env) }
      end
    end

    def default_controllers(options)
      mod = options[:module] || "devise"
      @controllers = Hash.new { |h,k| h[k] = "#{mod}/#{k}" }
      @controllers.merge!(options[:controllers]) if options[:controllers]
      @controllers.each { |k,v| @controllers[k] = v.to_s }
    end

    def default_path_names(options)
      @path_names = Hash.new { |h,k| h[k] = k.to_s }
      @path_names[:registration] = ""
      @path_names.merge!(options[:path_names]) if options[:path_names]
    end

    def default_constraints(options)
      @constraints = Hash.new
      @constraints.merge!(options[:constraints]) if options[:constraints]
    end

    def default_defaults(options)
      @defaults = Hash.new
      @defaults.merge!(options[:defaults]) if options[:defaults]
    end

    def default_used_route(options)
      singularizer = lambda { |s| s.to_s.singularize.to_sym }

      if options.has_key?(:only)
        @used_routes = self.routes & Array(options[:only]).map(&singularizer)
      elsif options[:skip] == :all
        @used_routes = []
      else
        @used_routes = self.routes - Array(options[:skip]).map(&singularizer)
      end
    end

    def default_used_helpers(options)
      singularizer = lambda { |s| s.to_s.singularize.to_sym }

      if options[:skip_helpers] == true
        @used_helpers = @used_routes
      elsif skip = options[:skip_helpers]
        @used_helpers = self.routes - Array(skip).map(&singularizer)
      else
        @used_helpers = self.routes
      end
    end
  end
end
