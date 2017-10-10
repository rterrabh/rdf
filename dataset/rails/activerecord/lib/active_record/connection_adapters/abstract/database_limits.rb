module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseLimits

      def table_alias_length
        255
      end

      def column_name_length
        64
      end

      def table_name_length
        64
      end

      def allowed_index_name_length
        index_name_length
      end

      def index_name_length
        64
      end

      def columns_per_table
        1024
      end

      def indexes_per_table
        16
      end

      def columns_per_multicolumn_index
        16
      end

      def in_clause_length
        nil
      end

      def sql_query_length
        1048575
      end

      def joins_per_query
        256
      end

    end
  end
end
