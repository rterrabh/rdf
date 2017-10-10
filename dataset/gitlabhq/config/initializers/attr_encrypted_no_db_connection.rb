module AttrEncrypted
  module Adapters
    module ActiveRecord
      def attribute_instance_methods_as_symbols_with_no_db_connection
        connected = ::ActiveRecord::Base.connection_pool.with_connection(&:active?) rescue false
        
        if connected
          attribute_instance_methods_as_symbols_without_no_db_connection
        else
          AttrEncrypted.instance_method(:attribute_instance_methods_as_symbols).bind(self).call
        end
      end

      alias_method_chain :attribute_instance_methods_as_symbols, :no_db_connection
    end
  end
end
