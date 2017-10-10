module Vagrant
  module Util
    module ScopedHashOverride
      def scoped_hash_override(original, scope)
        scope = scope.to_s

        result = original.dup

        original.each do |key, value|
          parts = key.to_s.split("__", 2)

          next if parts.length != 2

          if parts[0] == scope
            result[parts[1].to_sym] = value
          end
        end

        result
      end
    end
  end
end
