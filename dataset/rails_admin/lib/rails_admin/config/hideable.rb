module RailsAdmin
  module Config
    module Hideable
      def self.included(klass)
        klass.register_instance_option :visible? do
          !root.try :excluded?
        end
      end

      def hidden?
        !visible
      end

      def hide(&block)
        #nodyna <instance_eval-1407> <IEV COMPLEX (block execution)>
        visible block ? proc { false == (instance_eval(&block)) } : false
      end

      def show(&block)
        visible block || true
      end
    end
  end
end
