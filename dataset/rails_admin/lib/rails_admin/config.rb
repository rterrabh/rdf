require 'rails_admin/config/lazy_model'
require 'rails_admin/config/sections/list'
require 'active_support/core_ext/module/attribute_accessors'

module RailsAdmin
  module Config
    DEFAULT_AUTHENTICATION = proc {}

    DEFAULT_AUTHORIZE = proc {}

    DEFAULT_AUDIT = proc {}

    DEFAULT_CURRENT_USER = proc {}

    class << self
      attr_accessor :main_app_name

      attr_accessor :excluded_models

      attr_accessor :included_models

      attr_accessor :default_hidden_fields

      attr_accessor :default_items_per_page

      attr_reader :default_search_operator

      attr_accessor :label_methods

      attr_accessor :compact_show_view

      attr_accessor :browser_validations

      attr_accessor :total_columns_width

      attr_accessor :parent_controller

      attr_reader :registry

      attr_accessor :navigation_static_links
      attr_accessor :navigation_static_label

      attr_accessor :yell_for_non_accessible_fields

      def authenticate_with(&blk)
        @authenticate = blk if blk
        @authenticate || DEFAULT_AUTHENTICATION
      end

      def audit_with(*args, &block)
        extension = args.shift
        if extension
          @audit = proc do
            @auditing_adapter = RailsAdmin::AUDITING_ADAPTERS[extension].new(*([self] + args).compact)
          end
        else
          @audit = block if block
        end
        @audit || DEFAULT_AUDIT
      end

      def authorize_with(*args, &block)
        extension = args.shift
        if extension
          @authorize = proc do
            @authorization_adapter = RailsAdmin::AUTHORIZATION_ADAPTERS[extension].new(*([self] + args).compact)
          end
        else
          @authorize = block if block
        end
        @authorize || DEFAULT_AUTHORIZE
      end

      def configure_with(extension)
        configuration = RailsAdmin::CONFIGURATION_ADAPTERS[extension].new
        yield(configuration) if block_given?
      end

      def current_user_method(&block)
        @current_user = block if block
        @current_user || DEFAULT_CURRENT_USER
      end

      def default_search_operator=(operator)
        if %w(default like starts_with ends_with is =).include? operator
          @default_search_operator = operator
        else
          fail(ArgumentError.new("Search operator '#{operator}' not supported"))
        end
      end

      def models_pool
        excluded = (excluded_models.collect(&:to_s) + ['RailsAdmin::History'])

        (viable_models - excluded).uniq.sort
      end

      def model(entity, &block)
        key = begin
          if entity.is_a?(RailsAdmin::AbstractModel)
            entity.model.try(:name).try :to_sym
          elsif entity.is_a?(Class)
            entity.name.to_sym
          elsif entity.is_a?(String) || entity.is_a?(Symbol)
            entity.to_sym
          else
            entity.class.name.to_sym
          end
        end

        if block
          @registry[key] = RailsAdmin::Config::LazyModel.new(entity, &block)
        else
          @registry[key] ||= RailsAdmin::Config::LazyModel.new(entity)
        end
      end

      def default_hidden_fields=(fields)
        if fields.is_a?(Array)
          @default_hidden_fields = {}
          @default_hidden_fields[:edit] = fields
          @default_hidden_fields[:show] = fields
        else
          @default_hidden_fields = fields
        end
      end

      def actions(&block)
        #nodyna <instance_eval-1332> <IEV COMPLEX (block execution)>
        RailsAdmin::Config::Actions.instance_eval(&block) if block
      end

      def models
        RailsAdmin::AbstractModel.all.collect { |m| model(m) }
      end

      def reset
        @compact_show_view = true
        @browser_validations = true
        @yell_for_non_accessible_fields = true
        @authenticate = nil
        @authorize = nil
        @audit = nil
        @current_user = nil
        @default_hidden_fields = {}
        @default_hidden_fields[:base] = [:_type]
        @default_hidden_fields[:edit] = [:id, :_id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]
        @default_hidden_fields[:show] = [:id, :_id, :created_at, :created_on, :deleted_at, :updated_at, :updated_on, :deleted_on]
        @default_items_per_page = 20
        @default_search_operator = 'default'
        @excluded_models = []
        @included_models = []
        @total_columns_width = 697
        @label_methods = [:name, :title]
        @main_app_name = proc { [Rails.application.engine_name.titleize.chomp(' Application'), 'Admin'] }
        @registry = {}
        @navigation_static_links = {}
        @navigation_static_label = nil
        @parent_controller = '::ApplicationController'
        RailsAdmin::Config::Actions.reset
      end

      def reset_model(model)
        key = model.is_a?(Class) ? model.name.to_sym : model.to_sym
        @registry.delete(key)
      end


      def visible_models(bindings)
        visible_models_with_bindings(bindings).sort do |a, b|
          if (weight_order = a.weight <=> b.weight) == 0
            a.label.downcase <=> b.label.downcase
          else
            weight_order
          end
        end
      end

    private

      def lchomp(base, arg)
        base.to_s.reverse.chomp(arg.to_s.reverse).reverse
      end

      def viable_models
        included_models.collect(&:to_s).presence || begin
          @@system_models ||= # memoization for tests
            ([Rails.application] + Rails::Engine.subclasses.collect(&:instance)).flat_map do |app|
              (app.paths['app/models'].to_a + app.config.autoload_paths).collect do |load_path|
                Dir.glob(app.root.join(load_path)).collect do |load_dir|
                  Dir.glob(load_dir + '/**/*.rb').collect do |filename|
                    lchomp(filename, "#{app.root.join(load_dir)}/").chomp('.rb').camelize
                  end
                end
              end
            end.flatten.reject { |m| m.starts_with?('Concerns::') } # rubocop:disable MultilineBlockChain
        end
      end

      def visible_models_with_bindings(bindings)
        models.collect { |m| m.with(bindings) }.select do |m|
          m.visible? &&
            RailsAdmin::Config::Actions.find(:index, bindings.merge(abstract_model: m.abstract_model)).try(:authorized?) &&
            (!m.abstract_model.embedded? || m.abstract_model.cyclic?)
        end
      end
    end

    reset
  end
end
