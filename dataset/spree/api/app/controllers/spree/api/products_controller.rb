module Spree
  module Api
    class ProductsController < Spree::Api::BaseController

      def index
        if params[:ids]
          @products = product_scope.where(id: params[:ids].split(",").flatten)
        else
          @products = product_scope.ransack(params[:q]).result
        end

        @products = @products.distinct.page(params[:page]).per(params[:per_page])
        expires_in 15.minutes, :public => true
        headers['Surrogate-Control'] = "max-age=#{15.minutes}"
        respond_with(@products)
      end

      def show
        @product = find_product(params[:id])
        expires_in 15.minutes, :public => true
        headers['Surrogate-Control'] = "max-age=#{15.minutes}"
        headers['Surrogate-Key'] = "product_id=1"
        respond_with(@product)
      end

      def create
        authorize! :create, Spree::Product
        params[:product][:available_on] ||= Time.now
        set_up_shipping_category

        options = { variants_attrs: variants_params, options_attrs: option_types_params }
        @product = Spree::Core::Importer::Product.new(nil, product_params, options).create

        if @product.persisted?
          respond_with(@product, :status => 201, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def update
        @product = find_product(params[:id])
        authorize! :update, @product

        options = { variants_attrs: variants_params, options_attrs: option_types_params }
        @product = Spree::Core::Importer::Product.new(@product, product_params, options).update

        if @product.errors.empty?
          respond_with(@product.reload, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        @product = find_product(params[:id])
        authorize! :destroy, @product
        @product.destroy
        respond_with(@product, :status => 204)
      end

      private
        def product_params
          params.require(:product).permit(permitted_product_attributes)
        end

        def variants_params
          variants_key = if params[:product].has_key? :variants
            :variants
          else
            :variants_attributes
          end

          params.require(:product).permit(
            variants_key => [permitted_variant_attributes, :id],
          ).delete(variants_key) || []
        end

        def option_types_params
          params[:product].fetch(:option_types, [])
        end

        def set_up_shipping_category
          if shipping_category = params[:product].delete(:shipping_category)
            id = Spree::ShippingCategory.find_or_create_by(name: shipping_category).id
            params[:product][:shipping_category_id] = id
          end
        end
    end
  end
end
