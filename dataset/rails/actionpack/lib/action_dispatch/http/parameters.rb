require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/deprecation'

module ActionDispatch
  module Http
    module Parameters
      PARAMETERS_KEY = 'action_dispatch.request.path_parameters'

      def parameters
        @env["action_dispatch.request.parameters"] ||= begin
          params = begin
            request_parameters.merge(query_parameters)
          rescue EOFError
            query_parameters.dup
          end
          params.merge!(path_parameters)
        end
      end
      alias :params :parameters

      def path_parameters=(parameters) #:nodoc:
        @env.delete('action_dispatch.request.parameters')
        @env[PARAMETERS_KEY] = parameters
      end

      def symbolized_path_parameters
        ActiveSupport::Deprecation.warn(
          '`symbolized_path_parameters` is deprecated. Please use `path_parameters`.'
        )
        path_parameters
      end

      def path_parameters
        @env[PARAMETERS_KEY] ||= {}
      end

    private

      def normalize_encode_params(params)
        case params
        when Hash
          if params.has_key?(:tempfile)
            UploadedFile.new(params)
          else
            params.each_with_object({}) do |(key, val), new_hash|
              new_hash[key] = if val.is_a?(Array)
                val.map! { |el| normalize_encode_params(el) }
              else
                normalize_encode_params(val)
              end
            end.with_indifferent_access
          end
        else
          params
        end
      end
    end
  end
end
