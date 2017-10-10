module ActionView
  module Helpers
    module DebugHelper

      include TagHelper

      def debug(object)
        Marshal::dump(object)
        object = ERB::Util.html_escape(object.to_yaml)
        content_tag(:pre, object, :class => "debug_dump")
      rescue Exception  # errors from Marshal or YAML
        content_tag(:code, object.inspect, :class => "debug_dump")
      end
    end
  end
end
