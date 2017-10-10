module ActiveAdmin
  class Router
    def initialize(application)
      @application = application
    end

    def apply(router)
      define_root_routes router
      define_resource_routes router
    end

    def define_root_routes(router)
      #nodyna <instance_exec-76> <IEX COMPLEX (block without parameters)>
      router.instance_exec @application.namespaces do |namespaces|
        namespaces.each do |namespace|
          if namespace.root?
            root namespace.root_to_options.merge(to: namespace.root_to)
          else
            namespace namespace.name do
              root namespace.root_to_options.merge(to: namespace.root_to)
            end
          end
        end
      end
    end

    def define_resource_routes(router)
      #nodyna <instance_exec-77> <IEX COMPLEX (block without parameters)>
      router.instance_exec @application.namespaces, self do |namespaces, aa_router|
        resources = namespaces.flat_map{ |n| n.resources.values }
        resources.each do |config|
          routes = aa_router.resource_routes(config)

          if config.belongs_to?
            belongs_to = routes
            routes     = Proc.new do
              #nodyna <instance_exec-78> <IEX COMPLEX (block without parameters)>
              instance_exec &belongs_to if config.belongs_to_config.optional?

              resources config.belongs_to_config.target.resource_name.plural, only: [] do
                #nodyna <instance_exec-79> <IEX COMPLEX (block without parameters)>
                instance_exec &belongs_to
              end
            end
          end

          unless config.namespace.root?
            nested = routes
            routes = Proc.new do
              namespace config.namespace.name do
                #nodyna <instance_exec-80> <IEX COMPLEX (block without parameters)>
                instance_exec &nested
              end
            end
          end

          #nodyna <instance_exec-81> <IEX COMPLEX (block without parameters)>
          instance_exec &routes
        end
      end
    end

    def resource_routes(config)
      Proc.new do
        build_route  = proc{ |verbs, *args|
          #nodyna <send-82> <SD COMPLEX (array)>
          [*verbs].each{ |verb| send verb, *args }
        }
        build_action = proc{ |action|
          build_route.call(action.http_verb, action.name)
        }
        case config
        when ::ActiveAdmin::Resource
          resources config.resource_name.route_key, only: config.defined_actions do
            member do
              config.member_actions.each &build_action
            end

            collection do
              config.collection_actions.each &build_action
              post :batch_action if config.batch_actions_enabled?
            end
          end
        when ::ActiveAdmin::Page
          page = config.underscored_resource_name
          get "/#{page}" => "#{page}#index"
          config.page_actions.each do |action|
            build_route.call action.http_verb, "/#{page}/#{action.name}" => "#{page}##{action.name}"
          end
        else
          raise "Unsupported config class: #{config.class}"
        end
      end

    end
  end
end
