module Spree
  module Api
    class ZonesController < Spree::Api::BaseController

      def create
        authorize! :create, Spree::Zone
        @zone = Spree::Zone.new(map_nested_attributes_keys(Spree::Zone, zone_params))
        if @zone.save
          respond_with(@zone, :status => 201, :default_template => :show)
        else
          invalid_resource!(@zone)
        end
      end

      def destroy
        authorize! :destroy, zone
        zone.destroy
        respond_with(zone, :status => 204)
      end

      def index
        @zones = Spree::Zone.accessible_by(current_ability, :read).order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@zones)
      end

      def show
        respond_with(zone)
      end

      def update
        authorize! :update, zone
        if zone.update_attributes(map_nested_attributes_keys(Spree::Zone, zone_params))
          respond_with(zone, :status => 200, :default_template => :show)
        else
          invalid_resource!(zone)
        end
      end

      private
      def zone_params
        params.require(:zone).permit!
      end

      def zone
        @zone ||= Spree::Zone.accessible_by(current_ability, :read).find(params[:id])
      end
    end
  end
end
