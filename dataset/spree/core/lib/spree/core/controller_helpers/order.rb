module Spree
  module Core
    module ControllerHelpers
      module Order
        extend ActiveSupport::Concern

        included do
          before_filter :set_current_order

          helper_method :current_order
          helper_method :simple_current_order
        end

        def simple_current_order

          return @simple_current_order if @simple_current_order

          @simple_current_order = find_order_by_token_or_user

          if @simple_current_order
            @simple_current_order.last_ip_address = ip_address
            return @simple_current_order
          else
            @simple_current_order = Spree::Order.new
          end
        end

        def current_order(options = {})
          options[:create_order_if_necessary] ||= false

          return @current_order if @current_order

          @current_order = find_order_by_token_or_user(options, true)

          if options[:create_order_if_necessary] && (@current_order.nil? || @current_order.completed?)
            @current_order = Spree::Order.new(current_order_params)
            @current_order.user ||= try_spree_current_user
            @current_order.created_by ||= try_spree_current_user
            @current_order.save!
          end

          if @current_order
            @current_order.last_ip_address = ip_address
            return @current_order
          end
        end

        def associate_user
          @order ||= current_order
          if try_spree_current_user && @order
            @order.associate_user!(try_spree_current_user) if @order.user.blank? || @order.email.blank?
          end
        end

        def set_current_order
          if try_spree_current_user && current_order
            try_spree_current_user.orders.incomplete.where('id != ?', current_order.id).each do |order|
              current_order.merge!(order, try_spree_current_user)
            end
          end
        end

        def ip_address
          request.remote_ip
        end

        private

        def last_incomplete_order
          @last_incomplete_order ||= try_spree_current_user.last_incomplete_spree_order
        end

        def current_order_params
          { currency: current_currency, guest_token: cookies.signed[:guest_token], store_id: current_store.id, user_id: try_spree_current_user.try(:id) }
        end

        def find_order_by_token_or_user(options={}, with_adjustments = false)
          options[:lock] ||= false

          if with_adjustments
            order = Spree::Order.incomplete.includes(:adjustments).lock(options[:lock]).find_by(current_order_params)
          else
            order = Spree::Order.incomplete.lock(options[:lock]).find_by(current_order_params)
          end

          if order.nil? && try_spree_current_user
            order = last_incomplete_order
          end

          order
        end

      end
    end
  end
end
