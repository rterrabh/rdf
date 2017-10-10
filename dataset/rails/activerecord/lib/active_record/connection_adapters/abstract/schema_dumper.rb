module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module ColumnDumper
      def column_spec(column, types)
        spec = prepare_column_options(column, types)
        (spec.keys - [:name, :type]).each{ |k| spec[k].insert(0, "#{k}: ")}
        spec
      end

      def prepare_column_options(column, types)
        spec = {}
        spec[:name]      = column.name.inspect
        spec[:type]      = column.type.to_s
        spec[:null]      = 'false' unless column.null

        limit = column.limit || types[column.type][:limit]
        spec[:limit]     = limit.inspect if limit
        spec[:precision] = column.precision.inspect if column.precision
        spec[:scale]     = column.scale.inspect if column.scale

        default = schema_default(column) if column.has_default?
        spec[:default]   = default unless default.nil?

        spec
      end

      def migration_keys
        [:name, :limit, :precision, :scale, :default, :null]
      end

      private

      def schema_default(column)
        default = column.type_cast_from_database(column.default)
        unless default.nil?
          column.type_cast_for_schema(default)
        end
      end
    end
  end
end
