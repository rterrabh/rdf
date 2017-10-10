module ActiveAdmin
  class ResourceController < BaseController

    module DataAccess

      def self.included(base)
        base.class_exec do
          include Callbacks
          include ScopeChain

          define_active_admin_callbacks :build, :create, :update, :save, :destroy
        end
      end

      protected

      COLLECTION_APPLIES = [
        :authorization_scope,
        :sorting,
        :filtering,
        :scoping,
        :includes,
        :pagination,
        :collection_decorator
      ].freeze

      def collection
        get_collection_ivar || begin
          collection = find_collection
          authorize! Authorization::READ, active_admin_config.resource_class
          set_collection_ivar collection
        end
      end


      def find_collection(options = {})
        collection = scoped_collection
        collection_applies(options).each do |applyer|
          #nodyna <send-72> <SD COMPLEX (array)>
          collection = send("apply_#{applyer}", collection)
        end
        collection
      end


      def scoped_collection
        end_of_association_chain
      end

      def resource
        get_resource_ivar || begin
          resource = find_resource
          authorize_resource! resource

          resource = apply_decorator resource
          set_resource_ivar resource
        end
      end

      def find_resource
        #nodyna <send-73> <SD COMPLEX (change-prone variables)>
        scoped_collection.send method_for_find, params[:id]
      end


      def build_resource
        get_resource_ivar || begin
          resource = build_new_resource
          run_build_callbacks resource
          authorize_resource! resource

          resource = apply_decorator resource
          set_resource_ivar resource
        end
      end

      def build_new_resource
        #nodyna <send-74> <SD COMPLEX (change-prone variables)>
        scoped_collection.send method_for_build, *resource_params
      end

      def create_resource(object)
        run_create_callbacks object do
          save_resource(object)
        end
      end

      def save_resource(object)
        run_save_callbacks object do
          object.save
        end
      end

      def update_resource(object, attributes)
        if object.respond_to?(:assign_attributes)
          object.assign_attributes(*attributes)
        else
          object.attributes = attributes[0]
        end

        run_update_callbacks object do
          save_resource(object)
        end
      end

      def destroy_resource(object)
        run_destroy_callbacks object do
          object.destroy
        end
      end




      def apply_authorization_scope(collection)
        action_name = action_to_permission(params[:action])
        active_admin_authorization.scope_collection(collection, action_name)
      end

      def apply_sorting(chain)
        params[:order] ||= active_admin_config.sort_order

        order_clause = OrderClause.new params[:order]

        if order_clause.valid?
          chain.reorder(order_clause.to_sql(active_admin_config))
        else
          chain # just return the chain
        end
      end

      def apply_filtering(chain)
        @search = chain.ransack clean_search_params params[:q]
        @search.result
      end

      def clean_search_params(params)
        if params.is_a? Hash
          params.dup.delete_if{ |key, value| value.blank? }
        else
          {}
        end
      end

      def apply_scoping(chain)
        @collection_before_scope = chain

        if current_scope
          scope_chain(current_scope, chain)
        else
          chain
        end
      end

      def apply_includes(chain)
        if active_admin_config.includes.any?
          chain.includes *active_admin_config.includes
        else
          chain
        end
      end

      def collection_before_scope
        @collection_before_scope
      end

      def current_scope
        @current_scope ||= if params[:scope]
          active_admin_config.get_scope_by_id(params[:scope])
        else
          active_admin_config.default_scope(self)
        end
      end

      def apply_pagination(chain)
        page_method_name = Kaminari.config.page_method_name
        page = params[Kaminari.config.param_name]

        #nodyna <send-75> <SD COMPLEX (change-prone variables)>
        chain.public_send(page_method_name, page).per(per_page)
      end

      def collection_applies(options = {})
        only = Array(options.fetch(:only, COLLECTION_APPLIES))
        except = Array(options.fetch(:except, []))
        COLLECTION_APPLIES && only - except
      end

      def per_page
        if active_admin_config.paginate
          dynamic_per_page || configured_per_page
        else
          max_per_page
        end
      end

      def dynamic_per_page
        params[:per_page] || @per_page
      end

      def configured_per_page
        if active_admin_config.per_page.is_a?(Array)
          active_admin_config.per_page[0]
        else
          active_admin_config.per_page
        end
      end

      def max_per_page
        10_000
      end

    end
  end
end
