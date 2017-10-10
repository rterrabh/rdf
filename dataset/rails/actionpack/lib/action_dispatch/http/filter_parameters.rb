require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/duplicable'
require 'action_dispatch/http/parameter_filter'

module ActionDispatch
  module Http
    module FilterParameters
      ENV_MATCH = [/RAW_POST_DATA/, "rack.request.form_vars"] # :nodoc:
      NULL_PARAM_FILTER = ParameterFilter.new # :nodoc:
      NULL_ENV_FILTER   = ParameterFilter.new ENV_MATCH # :nodoc:

      def initialize(env)
        super
        @filtered_parameters = nil
        @filtered_env        = nil
        @filtered_path       = nil
      end

      def filtered_parameters
        @filtered_parameters ||= parameter_filter.filter(parameters)
      end

      def filtered_env
        @filtered_env ||= env_filter.filter(@env)
      end

      def filtered_path
        @filtered_path ||= query_string.empty? ? path : "#{path}?#{filtered_query_string}"
      end

    protected

      def parameter_filter
        parameter_filter_for @env.fetch("action_dispatch.parameter_filter") {
          return NULL_PARAM_FILTER
        }
      end

      def env_filter
        user_key = @env.fetch("action_dispatch.parameter_filter") {
          return NULL_ENV_FILTER
        }
        parameter_filter_for(Array(user_key) + ENV_MATCH)
      end

      def parameter_filter_for(filters)
        ParameterFilter.new(filters)
      end

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def filtered_query_string
        query_string.gsub(PAIR_RE) do |_|
          parameter_filter.filter([[$1, $2]]).first.join("=")
        end
      end
    end
  end
end
