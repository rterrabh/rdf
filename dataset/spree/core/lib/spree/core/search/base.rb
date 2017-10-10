module Spree
  module Core
    module Search
      class Base
        attr_accessor :properties
        attr_accessor :current_user
        attr_accessor :current_currency

        def initialize(params)
          self.current_currency = Spree::Config[:currency]
          @properties = {}
          prepare(params)
        end

        def retrieve_products
          @products = get_base_scope
          curr_page = page || 1

          unless Spree::Config.show_products_without_price
            @products = @products.where("spree_prices.amount IS NOT NULL").where("spree_prices.currency" => current_currency)
          end
          @products = @products.page(curr_page).per(per_page)
        end

        def method_missing(name)
          if @properties.has_key? name
            @properties[name]
          else
            super
          end
        end

        protected
          def get_base_scope
            base_scope = Spree::Product.active
            base_scope = base_scope.in_taxon(taxon) unless taxon.blank?
            base_scope = get_products_conditions_for(base_scope, keywords)
            base_scope = add_search_scopes(base_scope)
            base_scope = add_eagerload_scopes(base_scope)
            base_scope
          end

          def add_eagerload_scopes scope
            scope = scope.preload(master: :prices)
            scope = scope.preload(master: :images) if include_images
            scope
          end

          def add_search_scopes(base_scope)
            search.each do |name, scope_attribute|
              scope_name = name.to_sym
              if base_scope.respond_to?(:search_scopes) && base_scope.search_scopes.include?(scope_name.to_sym)
                #nodyna <send-2563> <SD COMPLEX (change-prone variables)>
                base_scope = base_scope.send(scope_name, *scope_attribute)
              else
                base_scope = base_scope.merge(Spree::Product.ransack({scope_name => scope_attribute}).result)
              end
            end if search
            base_scope
          end

          def get_products_conditions_for(base_scope, query)
            unless query.blank?
              base_scope = base_scope.like_any([:name, :description], query.split)
            end
            base_scope
          end

          def prepare(params)
            @properties[:taxon] = params[:taxon].blank? ? nil : Spree::Taxon.find(params[:taxon])
            @properties[:keywords] = params[:keywords]
            @properties[:search] = params[:search]
            @properties[:include_images] = params[:include_images]

            per_page = params[:per_page].to_i
            @properties[:per_page] = per_page > 0 ? per_page : Spree::Config[:products_per_page]
            if params[:page].respond_to?(:to_i)
              @properties[:page] = (params[:page].to_i <= 0) ? 1 : params[:page].to_i
            else
              @properties[:page] = 1
            end
          end
      end
    end
  end
end
