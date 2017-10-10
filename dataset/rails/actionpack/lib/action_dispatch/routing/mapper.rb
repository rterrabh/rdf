require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/string/filters'
require 'active_support/inflector'
require 'action_dispatch/routing/redirection'
require 'action_dispatch/routing/endpoint'
require 'active_support/deprecation'

module ActionDispatch
  module Routing
    class Mapper
      URL_OPTIONS = [:protocol, :subdomain, :domain, :host, :port]

      class Constraints < Endpoint #:nodoc:
        attr_reader :app, :constraints

        def initialize(app, constraints, dispatcher_p)
          if app.is_a?(self.class)
            constraints += app.constraints
            app = app.app
          end

          @dispatcher = dispatcher_p

          @app, @constraints, = app, constraints
        end

        def dispatcher?; @dispatcher; end

        def matches?(req)
          @constraints.all? do |constraint|
            (constraint.respond_to?(:matches?) && constraint.matches?(req)) ||
              (constraint.respond_to?(:call) && constraint.call(*constraint_args(constraint, req)))
          end
        end

        def serve(req)
          return [ 404, {'X-Cascade' => 'pass'}, [] ] unless matches?(req)

          if dispatcher?
            @app.serve req
          else
            @app.call req.env
          end
        end

        private
          def constraint_args(constraint, request)
            constraint.arity == 1 ? [request] : [request.path_parameters, request]
          end
      end

      class Mapping #:nodoc:
        ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}

        attr_reader :requirements, :conditions, :defaults
        attr_reader :to, :default_controller, :default_action, :as, :anchor

        def self.build(scope, set, path, as, options)
          options = scope[:options].merge(options) if scope[:options]

          options.delete :only
          options.delete :except
          options.delete :shallow_path
          options.delete :shallow_prefix
          options.delete :shallow

          defaults = (scope[:defaults] || {}).merge options.delete(:defaults) || {}

          new scope, set, path, defaults, as, options
        end

        def initialize(scope, set, path, defaults, as, options)
          @requirements, @conditions = {}, {}
          @defaults = defaults
          @set = set

          @to                 = options.delete :to
          @default_controller = options.delete(:controller) || scope[:controller]
          @default_action     = options.delete(:action) || scope[:action]
          @as                 = as
          @anchor             = options.delete :anchor

          formatted = options.delete :format
          via = Array(options.delete(:via) { [] })
          options_constraints = options.delete :constraints

          path = normalize_path! path, formatted
          ast  = path_ast path
          path_params = path_params ast

          options = normalize_options!(options, formatted, path_params, ast, scope[:module])


          split_constraints(path_params, scope[:constraints]) if scope[:constraints]
          constraints = constraints(options, path_params)

          split_constraints path_params, constraints

          @blocks = blocks(options_constraints, scope[:blocks])

          if options_constraints.is_a?(Hash)
            split_constraints path_params, options_constraints
            options_constraints.each do |key, default|
              if URL_OPTIONS.include?(key) && (String === default || Fixnum === default)
                @defaults[key] ||= default
              end
            end
          end

          normalize_format!(formatted)

          @conditions[:path_info] = path
          @conditions[:parsed_path_info] = ast

          add_request_method(via, @conditions)
          normalize_defaults!(options)
        end

        def to_route
          [ app(@blocks), conditions, requirements, defaults, as, anchor ]
        end

        private

          def normalize_path!(path, format)
            path = Mapper.normalize_path(path)

            if format == true
              "#{path}.:format"
            elsif optional_format?(path, format)
              "#{path}(.:format)"
            else
              path
            end
          end

          def optional_format?(path, format)
            format != false && !path.include?(':format') && !path.end_with?('/')
          end

          def normalize_options!(options, formatted, path_params, path_ast, modyoule)
            if formatted != false
              path_ast.grep(Journey::Nodes::Star) do |node|
                options[node.name.to_sym] ||= /.+?/
              end
            end

            if path_params.include?(:controller)
              raise ArgumentError, ":controller segment is not allowed within a namespace block" if modyoule

              options[:controller] ||= /.+?/
            end

            if to.respond_to? :call
              options
            else
              to_endpoint = split_to to
              controller  = to_endpoint[0] || default_controller
              action      = to_endpoint[1] || default_action

              controller = add_controller_module(controller, modyoule)

              options.merge! check_controller_and_action(path_params, controller, action)
            end
          end

          def split_constraints(path_params, constraints)
            constraints.each_pair do |key, requirement|
              if path_params.include?(key) || key == :controller
                verify_regexp_requirement(requirement) if requirement.is_a?(Regexp)
                @requirements[key] = requirement
              else
                @conditions[key] = requirement
              end
            end
          end

          def normalize_format!(formatted)
            if formatted == true
              @requirements[:format] ||= /.+/
            elsif Regexp === formatted
              @requirements[:format] = formatted
              @defaults[:format] = nil
            elsif String === formatted
              @requirements[:format] = Regexp.compile(formatted)
              @defaults[:format] = formatted
            end
          end

          def verify_regexp_requirement(requirement)
            if requirement.source =~ ANCHOR_CHARACTERS_REGEX
              raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
            end

            if requirement.multiline?
              raise ArgumentError, "Regexp multiline option is not allowed in routing requirements: #{requirement.inspect}"
            end
          end

          def normalize_defaults!(options)
            options.each_pair do |key, default|
              unless Regexp === default
                @defaults[key] = default
              end
            end
          end

          def verify_callable_constraint(callable_constraint)
            unless callable_constraint.respond_to?(:call) || callable_constraint.respond_to?(:matches?)
              raise ArgumentError, "Invalid constraint: #{callable_constraint.inspect} must respond to :call or :matches?"
            end
          end

          def add_request_method(via, conditions)
            return if via == [:all]

            if via.empty?
              msg = "You should not use the `match` method in your router without specifying an HTTP method.\n" \
                    "If you want to expose your action to both GET and POST, add `via: [:get, :post]` option.\n" \
                    "If you want to expose your action to GET, use `get` in the router:\n" \
                    "  Instead of: match \"controller#action\"\n" \
                    "  Do: get \"controller#action\""
              raise ArgumentError, msg
            end

            conditions[:request_method] = via.map { |m| m.to_s.dasherize.upcase }
          end

          def app(blocks)
            if to.respond_to?(:call)
              Constraints.new(to, blocks, false)
            elsif blocks.any?
              Constraints.new(dispatcher(defaults), blocks, true)
            else
              dispatcher(defaults)
            end
          end

          def check_controller_and_action(path_params, controller, action)
            hash = check_part(:controller, controller, path_params, {}) do |part|
              translate_controller(part) {
                message = "'#{part}' is not a supported controller name. This can lead to potential routing problems."
                message << " See http://guides.rubyonrails.org/routing.html#specifying-a-controller-to-use"

                raise ArgumentError, message
              }
            end

            check_part(:action, action, path_params, hash) { |part|
              part.is_a?(Regexp) ? part : part.to_s
            }
          end

          def check_part(name, part, path_params, hash)
            if part
              hash[name] = yield(part)
            else
              unless path_params.include?(name)
                message = "Missing :#{name} key on routes definition, please check your routes."
                raise ArgumentError, message
              end
            end
            hash
          end

          def split_to(to)
            case to
            when Symbol
              ActiveSupport::Deprecation.warn(<<-MSG.squish)
                Defining a route where `to` is a symbol is deprecated.
                Please change `to: :#{to}` to `action: :#{to}`.
              MSG

              [nil, to.to_s]
            when /#/    then to.split('#')
            when String
              ActiveSupport::Deprecation.warn(<<-MSG.squish)
                Defining a route where `to` is a controller without an action is deprecated.
                Please change `to: '#{to}'` to `controller: '#{to}'`.
              MSG

              [to, nil]
            else
              []
            end
          end

          def add_controller_module(controller, modyoule)
            if modyoule && !controller.is_a?(Regexp)
              if controller =~ %r{\A/}
                controller[1..-1]
              else
                [modyoule, controller].compact.join("/")
              end
            else
              controller
            end
          end

          def translate_controller(controller)
            return controller if Regexp === controller
            return controller.to_s if controller =~ /\A[a-z_0-9][a-z_0-9\/]*\z/

            yield
          end

          def blocks(options_constraints, scope_blocks)
            if options_constraints && !options_constraints.is_a?(Hash)
              verify_callable_constraint(options_constraints)
              [options_constraints]
            else
              scope_blocks || []
            end
          end

          def constraints(options, path_params)
            constraints = {}
            required_defaults = []
            options.each_pair do |key, option|
              if Regexp === option
                constraints[key] = option
              else
                required_defaults << key unless path_params.include?(key)
              end
            end
            @conditions[:required_defaults] = required_defaults
            constraints
          end

          def path_params(ast)
            ast.grep(Journey::Nodes::Symbol).map { |n| n.name.to_sym }
          end

          def path_ast(path)
            parser = Journey::Parser.new
            parser.parse path
          end

          def dispatcher(defaults)
            @set.dispatcher defaults
          end
      end

      def self.normalize_path(path)
        path = Journey::Router::Utils.normalize_path(path)
        path.gsub!(%r{/(\(+)/?}, '\1/') unless path =~ %r{^/\(+[^)]+\)$}
        path
      end

      def self.normalize_name(name)
        normalize_path(name)[1..-1].tr("/", "_")
      end

      module Base
        def root(options = {})
          match '/', { :as => :root, :via => :get }.merge!(options)
        end

        def match(path, options=nil)
        end

        def mount(app, options = nil)
          if options
            path = options.delete(:at)
          else
            unless Hash === app
              raise ArgumentError, "must be called with mount point"
            end

            options = app
            app, path = options.find { |k, _| k.respond_to?(:call) }
            options.delete(app) if app
          end

          raise "A rack application must be specified" unless path

          rails_app = rails_app? app
          options[:as] ||= app_name(app, rails_app)

          target_as       = name_for_action(options[:as], path)
          options[:via] ||= :all

          match(path, options.merge(:to => app, :anchor => false, :format => false))

          define_generate_prefix(app, target_as) if rails_app
          self
        end

        def default_url_options=(options)
          @set.default_url_options = options
        end
        alias_method :default_url_options, :default_url_options=

        def with_default_scope(scope, &block)
          scope(scope) do
            #nodyna <instance_exec-1269> <IEX COMPLEX (block without parameters)>
            instance_exec(&block)
          end
        end

        def has_named_route?(name)
          @set.named_routes.routes[name.to_sym]
        end

        private
          def rails_app?(app)
            app.is_a?(Class) && app < Rails::Railtie
          end

          def app_name(app, rails_app)
            if rails_app
              app.railtie_name
            elsif app.is_a?(Class)
              class_name = app.name
              ActiveSupport::Inflector.underscore(class_name).tr("/", "_")
            end
          end

          def define_generate_prefix(app, name)
            _route = @set.named_routes.get name
            _routes = @set
            app.routes.define_mounted_helper(name)
            app.routes.extend Module.new {
              def optimize_routes_generation?; false; end
              #nodyna <define_method-1270> <DM MODERATE (events)>
              define_method :find_script_name do |options|
                if options.key? :script_name
                  super(options)
                else
                  prefix_options = options.slice(*_route.segment_keys)
                  _route.segment_keys.each { |k| options.delete(k) }
                  #nodyna <send-1271> <SD COMPLEX (change-prone variables)>
                  _routes.url_helpers.send("#{name}_path", prefix_options)
                end
              end
            }
          end
      end

      module HttpHelpers
        def get(*args, &block)
          map_method(:get, args, &block)
        end

        def post(*args, &block)
          map_method(:post, args, &block)
        end

        def patch(*args, &block)
          map_method(:patch, args, &block)
        end

        def put(*args, &block)
          map_method(:put, args, &block)
        end

        def delete(*args, &block)
          map_method(:delete, args, &block)
        end

        private
          def map_method(method, args, &block)
            options = args.extract_options!
            options[:via] = method
            match(*args, options, &block)
            self
          end
      end

      module Scoping
        def scope(*args)
          options = args.extract_options!.dup
          scope = {}

          options[:path] = args.flatten.join('/') if args.any?
          options[:constraints] ||= {}

          unless nested_scope?
            options[:shallow_path] ||= options[:path] if options.key?(:path)
            options[:shallow_prefix] ||= options[:as] if options.key?(:as)
          end

          if options[:constraints].is_a?(Hash)
            defaults = options[:constraints].select do
              |k, v| URL_OPTIONS.include?(k) && (v.is_a?(String) || v.is_a?(Fixnum))
            end

            (options[:defaults] ||= {}).reverse_merge!(defaults)
          else
            block, options[:constraints] = options[:constraints], {}
          end

          @scope.options.each do |option|
            if option == :blocks
              value = block
            elsif option == :options
              value = options
            else
              value = options.delete(option)
            end

            if value
              #nodyna <send-1272> <SD COMPLEX (change-prone variables)>
              scope[option] = send("merge_#{option}_scope", @scope[option], value)
            end
          end

          @scope = @scope.new scope
          yield
          self
        ensure
          @scope = @scope.parent
        end

        def controller(controller, options={})
          options[:controller] = controller
          scope(options) { yield }
        end

        def namespace(path, options = {})
          path = path.to_s

          defaults = {
            module:         path,
            path:           options.fetch(:path, path),
            as:             options.fetch(:as, path),
            shallow_path:   options.fetch(:path, path),
            shallow_prefix: options.fetch(:as, path)
          }

          scope(defaults.merge!(options)) { yield }
        end

        def constraints(constraints = {})
          scope(:constraints => constraints) { yield }
        end

        def defaults(defaults = {})
          scope(:defaults => defaults) { yield }
        end

        private
          def merge_path_scope(parent, child) #:nodoc:
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_shallow_path_scope(parent, child) #:nodoc:
            Mapper.normalize_path("#{parent}/#{child}")
          end

          def merge_as_scope(parent, child) #:nodoc:
            parent ? "#{parent}_#{child}" : child
          end

          def merge_shallow_prefix_scope(parent, child) #:nodoc:
            parent ? "#{parent}_#{child}" : child
          end

          def merge_module_scope(parent, child) #:nodoc:
            parent ? "#{parent}/#{child}" : child
          end

          def merge_controller_scope(parent, child) #:nodoc:
            child
          end

          def merge_action_scope(parent, child) #:nodoc:
            child
          end

          def merge_path_names_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_constraints_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_defaults_scope(parent, child) #:nodoc:
            merge_options_scope(parent, child)
          end

          def merge_blocks_scope(parent, child) #:nodoc:
            merged = parent ? parent.dup : []
            merged << child if child
            merged
          end

          def merge_options_scope(parent, child) #:nodoc:
            (parent || {}).except(*override_keys(child)).merge!(child)
          end

          def merge_shallow_scope(parent, child) #:nodoc:
            child ? true : false
          end

          def override_keys(child) #:nodoc:
            child.key?(:only) || child.key?(:except) ? [:only, :except] : []
          end
      end

      module Resources
        VALID_ON_OPTIONS  = [:new, :collection, :member]
        RESOURCE_OPTIONS  = [:as, :controller, :path, :only, :except, :param, :concerns]
        CANONICAL_ACTIONS = %w(index create new show update destroy)

        class Resource #:nodoc:
          attr_reader :controller, :path, :options, :param

          def initialize(entities, options = {})
            @name       = entities.to_s
            @path       = (options[:path] || @name).to_s
            @controller = (options[:controller] || @name).to_s
            @as         = options[:as]
            @param      = (options[:param] || :id).to_sym
            @options    = options
            @shallow    = false
          end

          def default_actions
            [:index, :create, :new, :show, :update, :destroy, :edit]
          end

          def actions
            if only = @options[:only]
              Array(only).map(&:to_sym)
            elsif except = @options[:except]
              default_actions - Array(except).map(&:to_sym)
            else
              default_actions
            end
          end

          def name
            @as || @name
          end

          def plural
            @plural ||= name.to_s
          end

          def singular
            @singular ||= name.to_s.singularize
          end

          alias :member_name :singular

          def collection_name
            singular == plural ? "#{plural}_index" : plural
          end

          def resource_scope
            { :controller => controller }
          end

          alias :collection_scope :path

          def member_scope
            "#{path}/:#{param}"
          end

          alias :shallow_scope :member_scope

          def new_scope(new_path)
            "#{path}/#{new_path}"
          end

          def nested_param
            :"#{singular}_#{param}"
          end

          def nested_scope
            "#{path}/:#{nested_param}"
          end

          def shallow=(value)
            @shallow = value
          end

          def shallow?
            @shallow
          end
        end

        class SingletonResource < Resource #:nodoc:
          def initialize(entities, options)
            super
            @as         = nil
            @controller = (options[:controller] || plural).to_s
            @as         = options[:as]
          end

          def default_actions
            [:show, :create, :update, :destroy, :new, :edit]
          end

          def plural
            @plural ||= name.to_s.pluralize
          end

          def singular
            @singular ||= name.to_s
          end

          alias :member_name :singular
          alias :collection_name :singular

          alias :member_scope :path
          alias :nested_scope :path
        end

        def resources_path_names(options)
          @scope[:path_names].merge!(options)
        end

        def resource(*resources, &block)
          options = resources.extract_options!.dup

          if apply_common_behavior_for(:resource, resources, options, &block)
            return self
          end

          resource_scope(:resource, SingletonResource.new(resources.pop, options)) do
            yield if block_given?

            concerns(options[:concerns]) if options[:concerns]

            collection do
              post :create
            end if parent_resource.actions.include?(:create)

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            set_member_mappings_for_resource
          end

          self
        end

        def resources(*resources, &block)
          options = resources.extract_options!.dup

          if apply_common_behavior_for(:resources, resources, options, &block)
            return self
          end

          resource_scope(:resources, Resource.new(resources.pop, options)) do
            yield if block_given?

            concerns(options[:concerns]) if options[:concerns]

            collection do
              get  :index if parent_resource.actions.include?(:index)
              post :create if parent_resource.actions.include?(:create)
            end

            new do
              get :new
            end if parent_resource.actions.include?(:new)

            set_member_mappings_for_resource
          end

          self
        end

        def collection
          unless resource_scope?
            raise ArgumentError, "can't use collection outside resource(s) scope"
          end

          with_scope_level(:collection) do
            scope(parent_resource.collection_scope) do
              yield
            end
          end
        end

        def member
          unless resource_scope?
            raise ArgumentError, "can't use member outside resource(s) scope"
          end

          with_scope_level(:member) do
            if shallow?
              shallow_scope(parent_resource.member_scope) { yield }
            else
              scope(parent_resource.member_scope) { yield }
            end
          end
        end

        def new
          unless resource_scope?
            raise ArgumentError, "can't use new outside resource(s) scope"
          end

          with_scope_level(:new) do
            scope(parent_resource.new_scope(action_path(:new))) do
              yield
            end
          end
        end

        def nested
          unless resource_scope?
            raise ArgumentError, "can't use nested outside resource(s) scope"
          end

          with_scope_level(:nested) do
            if shallow? && shallow_nesting_depth >= 1
              shallow_scope(parent_resource.nested_scope, nested_options) { yield }
            else
              scope(parent_resource.nested_scope, nested_options) { yield }
            end
          end
        end

        def namespace(path, options = {})
          if resource_scope?
            nested { super }
          else
            super
          end
        end

        def shallow
          scope(:shallow => true) do
            yield
          end
        end

        def shallow?
          parent_resource.instance_of?(Resource) && @scope[:shallow]
        end

        def match(path, *rest)
          if rest.empty? && Hash === path
            options  = path
            path, to = options.find { |name, _value| name.is_a?(String) }

            case to
            when Symbol
              options[:action] = to
            when String
              if to =~ /#/
                options[:to] = to
              else
                options[:controller] = to
              end
            else
              options[:to] = to
            end

            options.delete(path)
            paths = [path]
          else
            options = rest.pop || {}
            paths = [path] + rest
          end

          options[:anchor] = true unless options.key?(:anchor)

          if options[:on] && !VALID_ON_OPTIONS.include?(options[:on])
            raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
          end

          if @scope[:controller] && @scope[:action]
            options[:to] ||= "#{@scope[:controller]}##{@scope[:action]}"
          end

          paths.each do |_path|
            route_options = options.dup
            route_options[:path] ||= _path if _path.is_a?(String)

            path_without_format = _path.to_s.sub(/\(\.:format\)$/, '')
            if using_match_shorthand?(path_without_format, route_options)
              route_options[:to] ||= path_without_format.gsub(%r{^/}, "").sub(%r{/([^/]*)$}, '#\1')
              route_options[:to].tr!("-", "_")
            end

            decomposed_match(_path, route_options)
          end
          self
        end

        def using_match_shorthand?(path, options)
          path && (options[:to] || options[:action]).nil? && path =~ %r{^/?[-\w]+/[-\w/]+$}
        end

        def decomposed_match(path, options) # :nodoc:
          if on = options.delete(:on)
            #nodyna <send-1273> <SD COMPLEX (change-prone variables)>
            send(on) { decomposed_match(path, options) }
          else
            case @scope.scope_level
            when :resources
              nested { decomposed_match(path, options) }
            when :resource
              member { decomposed_match(path, options) }
            else
              add_route(path, options)
            end
          end
        end

        def add_route(action, options) # :nodoc:
          path = path_for_action(action, options.delete(:path))
          raise ArgumentError, "path is required" if path.blank?

          action = action.to_s.dup

          if action =~ /^[\w\-\/]+$/
            options[:action] ||= action.tr('-', '_') unless action.include?("/")
          else
            action = nil
          end

          as = if !options.fetch(:as, true) # if it's set to nil or false
                 options.delete(:as)
               else
                 name_for_action(options.delete(:as), action)
               end

          mapping = Mapping.build(@scope, @set, URI.parser.escape(path), as, options)
          app, conditions, requirements, defaults, as, anchor = mapping.to_route
          @set.add_route(app, conditions, requirements, defaults, as, anchor)
        end

        def root(path, options={})
          if path.is_a?(String)
            options[:to] = path
          elsif path.is_a?(Hash) and options.empty?
            options = path
          else
            raise ArgumentError, "must be called with a path and/or options"
          end

          if @scope.resources?
            with_scope_level(:root) do
              scope(parent_resource.path) do
                super(options)
              end
            end
          else
            super(options)
          end
        end

        protected

          def parent_resource #:nodoc:
            @scope[:scope_level_resource]
          end

          def apply_common_behavior_for(method, resources, options, &block) #:nodoc:
            if resources.length > 1
              #nodyna <send-1274> <SD MODERATE (array)>
              resources.each { |r| send(method, r, options, &block) }
              return true
            end

            if options.delete(:shallow)
              shallow do
                #nodyna <send-1275> <SD MODERATE (change-prone variables)>
                send(method, resources.pop, options, &block)
              end
              return true
            end

            if resource_scope?
              #nodyna <send-1276> <SD MODERATE (change-prone variables)>
              nested { send(method, resources.pop, options, &block) }
              return true
            end

            options.keys.each do |k|
              (options[:constraints] ||= {})[k] = options.delete(k) if options[k].is_a?(Regexp)
            end

            scope_options = options.slice!(*RESOURCE_OPTIONS)
            unless scope_options.empty?
              scope(scope_options) do
                #nodyna <send-1277> <SD MODERATE (change-prone variables)>
                send(method, resources.pop, options, &block)
              end
              return true
            end

            unless action_options?(options)
              options.merge!(scope_action_options) if scope_action_options?
            end

            false
          end

          def action_options?(options) #:nodoc:
            options[:only] || options[:except]
          end

          def scope_action_options? #:nodoc:
            @scope[:options] && (@scope[:options][:only] || @scope[:options][:except])
          end

          def scope_action_options #:nodoc:
            @scope[:options].slice(:only, :except)
          end

          def resource_scope? #:nodoc:
            @scope.resource_scope?
          end

          def resource_method_scope? #:nodoc:
            @scope.resource_method_scope?
          end

          def nested_scope? #:nodoc:
            @scope.nested?
          end

          def with_exclusive_scope
            begin
              @scope = @scope.new(:as => nil, :path => nil)

              with_scope_level(:exclusive) do
                yield
              end
            ensure
              @scope = @scope.parent
            end
          end

          def with_scope_level(kind)
            @scope = @scope.new_level(kind)
            yield
          ensure
            @scope = @scope.parent
          end

          def resource_scope(kind, resource) #:nodoc:
            resource.shallow = @scope[:shallow]
            @scope = @scope.new(:scope_level_resource => resource)
            @nesting.push(resource)

            with_scope_level(kind) do
              scope(parent_resource.resource_scope) { yield }
            end
          ensure
            @nesting.pop
            @scope = @scope.parent
          end

          def nested_options #:nodoc:
            options = { :as => parent_resource.member_name }
            options[:constraints] = {
              parent_resource.nested_param => param_constraint
            } if param_constraint?

            options
          end

          def nesting_depth #:nodoc:
            @nesting.size
          end

          def shallow_nesting_depth #:nodoc:
            @nesting.select(&:shallow?).size
          end

          def param_constraint? #:nodoc:
            @scope[:constraints] && @scope[:constraints][parent_resource.param].is_a?(Regexp)
          end

          def param_constraint #:nodoc:
            @scope[:constraints][parent_resource.param]
          end

          def canonical_action?(action) #:nodoc:
            resource_method_scope? && CANONICAL_ACTIONS.include?(action.to_s)
          end

          def shallow_scope(path, options = {}) #:nodoc:
            scope = { :as   => @scope[:shallow_prefix],
                      :path => @scope[:shallow_path] }
            @scope = @scope.new scope

            scope(path, options) { yield }
          ensure
            @scope = @scope.parent
          end

          def path_for_action(action, path) #:nodoc:
            if path.blank? && canonical_action?(action)
              @scope[:path].to_s
            else
              "#{@scope[:path]}/#{action_path(action, path)}"
            end
          end

          def action_path(name, path = nil) #:nodoc:
            name = name.to_sym if name.is_a?(String)
            path || @scope[:path_names][name] || name.to_s
          end

          def prefix_name_for_action(as, action) #:nodoc:
            if as
              prefix = as
            elsif !canonical_action?(action)
              prefix = action
            end

            if prefix && prefix != '/' && !prefix.empty?
              Mapper.normalize_name prefix.to_s.tr('-', '_')
            end
          end

          def name_for_action(as, action) #:nodoc:
            prefix = prefix_name_for_action(as, action)
            name_prefix = @scope[:as]

            if parent_resource
              return nil unless as || action

              collection_name = parent_resource.collection_name
              member_name = parent_resource.member_name
            end

            name = @scope.action_name(name_prefix, prefix, collection_name, member_name)

            if candidate = name.compact.join("_").presence
              if as.nil?
                candidate unless candidate !~ /\A[_a-z]/i || @set.named_routes.key?(candidate)
              else
                candidate
              end
            end
          end

          def set_member_mappings_for_resource
            member do
              get :edit if parent_resource.actions.include?(:edit)
              get :show if parent_resource.actions.include?(:show)
              if parent_resource.actions.include?(:update)
                patch :update
                put   :update
              end
              delete :destroy if parent_resource.actions.include?(:destroy)
            end
          end
      end

      module Concerns
        def concern(name, callable = nil, &block)
          #nodyna <instance_exec-1278> <IEX COMPLEX (block with parameters)>
          callable ||= lambda { |mapper, options| mapper.instance_exec(options, &block) }
          @concerns[name] = callable
        end

        def concerns(*args)
          options = args.extract_options!
          args.flatten.each do |name|
            if concern = @concerns[name]
              concern.call(self, options)
            else
              raise ArgumentError, "No concern named #{name} was found!"
            end
          end
        end
      end

      class Scope # :nodoc:
        OPTIONS = [:path, :shallow_path, :as, :shallow_prefix, :module,
                   :controller, :action, :path_names, :constraints,
                   :shallow, :blocks, :defaults, :options]

        RESOURCE_SCOPES = [:resource, :resources]
        RESOURCE_METHOD_SCOPES = [:collection, :member, :new]

        attr_reader :parent, :scope_level

        def initialize(hash, parent = {}, scope_level = nil)
          @hash = hash
          @parent = parent
          @scope_level = scope_level
        end

        def nested?
          scope_level == :nested
        end

        def resources?
          scope_level == :resources
        end

        def resource_method_scope?
          RESOURCE_METHOD_SCOPES.include? scope_level
        end

        def action_name(name_prefix, prefix, collection_name, member_name)
          case scope_level
          when :nested
            [name_prefix, prefix]
          when :collection
            [prefix, name_prefix, collection_name]
          when :new
            [prefix, :new, name_prefix, member_name]
          when :member
            [prefix, name_prefix, member_name]
          when :root
            [name_prefix, collection_name, prefix]
          else
            [name_prefix, member_name, prefix]
          end
        end

        def resource_scope?
          RESOURCE_SCOPES.include? scope_level
        end

        def options
          OPTIONS
        end

        def new(hash)
          self.class.new hash, self, scope_level
        end

        def new_level(level)
          self.class.new(self, self, level)
        end

        def fetch(key, &block)
          @hash.fetch(key, &block)
        end

        def [](key)
          @hash.fetch(key) { @parent[key] }
        end

        def []=(k,v)
          @hash[k] = v
        end
      end

      def initialize(set) #:nodoc:
        @set = set
        @scope = Scope.new({ :path_names => @set.resources_path_names })
        @concerns = {}
        @nesting = []
      end

      include Base
      include HttpHelpers
      include Redirection
      include Scoping
      include Concerns
      include Resources
    end
  end
end
