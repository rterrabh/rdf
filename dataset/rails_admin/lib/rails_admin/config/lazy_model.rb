require 'rails_admin/config/model'

module RailsAdmin
  module Config
    class LazyModel
      def initialize(entity, &block)
        @entity = entity
        @deferred_block = block
      end

      def target
        unless @model
          @model = RailsAdmin::Config::Model.new(@entity)
          #nodyna <ID:instance_eval-12> <IEV COMPLEX (block execution)>
          @model.instance_eval(&@deferred_block) if @deferred_block
        end
        @model
      end

      def method_missing(method, *args, &block)
        #nodyna <ID:send-36> <SD COMPLEX (change-prone variables)>
        target.send(method, *args, &block)
      end

      def respond_to?(method, include_private = false)
        super || target.respond_to?(method, include_private)
      end
    end
  end
end
