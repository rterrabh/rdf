module Grape
  module Middleware
    class Filter < Base
      def before
        #nodyna <instance_eval-2811> <IEV COMPLEX (block execution)>
        app.instance_eval(&options[:before]) if options[:before]
      end

      def after
        #nodyna <instance_eval-2812> <IEV COMPLEX (block execution)>
        app.instance_eval(&options[:after]) if options[:after]
      end
    end
  end
end
