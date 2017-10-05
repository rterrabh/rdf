module Spree
  module Core
    class Engine < ::Rails::Engine
      def self.add_routes(&block)
        @spree_routes ||= []

        unless @spree_routes.include?(block)
          @spree_routes << block
        end
      end

      def self.append_routes(&block)
        @append_routes ||= []
        unless @append_routes.include?(block)
          @append_routes << block
        end
      end

      def self.draw_routes(&block)
        @spree_routes ||= []
        @append_routes ||= []
        eval_block(block) if block_given?
        @spree_routes.each { |r| eval_block(&r) }
        @append_routes.each { |r| eval_block(&r) }
        @spree_routes = []
        @append_routes = []
      end

      def eval_block(&block)
        #nodyna <send-1> <SEND TRIVIAL (static values)>
        Spree::Core::Engine.routes.send :eval_block, block
      end
    end
  end
end
