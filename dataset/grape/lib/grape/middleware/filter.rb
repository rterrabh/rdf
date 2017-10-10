module Grape
  module Middleware
    class Filter < Base
      def before
        #nodyna <instance_eval-2811> <not yet classified>
        app.instance_eval(&options[:before]) if options[:before]
      end

      def after
        #nodyna <instance_eval-2812> <not yet classified>
        app.instance_eval(&options[:after]) if options[:after]
      end
    end
  end
end
