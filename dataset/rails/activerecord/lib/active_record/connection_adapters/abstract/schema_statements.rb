require 'active_record/migration/join_table'
require 'active_support/core_ext/string/access'
require 'digest'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      include ActiveRecord::Migration::JoinTable

      def native_database_types
        {}
      end

      def table_alias_for(table_name)
        table_name[0...table_alias_length].tr('.', '_')
      end

      def table_exists?(table_name)
        tables.include?(table_name.to_s)
      end


      def index_exists?(table_name, column_name, options = {})
        column_names = Array(column_name).map(&:to_s)
        index_name = options.key?(:name) ? options[:name].to_s : index_name(table_name, column: column_names)
        checks = []
        checks << lambda { |i| i.name == index_name }
        checks << lambda { |i| i.columns == column_names }
        checks << lambda { |i| i.unique } if options[:unique]

        indexes(table_name).any? { |i| checks.all? { |check| check[i] } }
      end

      def columns(table_name) end

      def column_exists?(table_name, column_name, type = nil, options = {})
        column_name = column_name.to_s
        columns(table_name).any?{ |c| c.name == column_name &&
                                      (!type                     || c.type == type) &&
                                      (!options.key?(:limit)     || c.limit == options[:limit]) &&
                                      (!options.key?(:precision) || c.precision == options[:precision]) &&
                                      (!options.key?(:scale)     || c.scale == options[:scale]) &&
                                      (!options.key?(:default)   || c.default == options[:default]) &&
                                      (!options.key?(:null)      || c.null == options[:null]) }
      end

      def create_table(table_name, options = {})
        td = create_table_definition table_name, options[:temporary], options[:options], options[:as]

        if options[:id] != false && !options[:as]
          pk = options.fetch(:primary_key) do
            Base.get_primary_key table_name.to_s.singularize
          end

          td.primary_key pk, options.fetch(:id, :primary_key), options
        end

        yield td if block_given?

        if options[:force] && table_exists?(table_name)
          drop_table(table_name, options)
        end

        result = execute schema_creation.accept td

        unless supports_indexes_in_create?
          td.indexes.each_pair do |column_name, index_options|
            add_index(table_name, column_name, index_options)
          end
        end

        td.foreign_keys.each_pair do |other_table_name, foreign_key_options|
          add_foreign_key(table_name, other_table_name, foreign_key_options)
        end

        result
      end

      def create_join_table(table_1, table_2, options = {})
        join_table_name = find_join_table_name(table_1, table_2, options)

        column_options = options.delete(:column_options) || {}
        column_options.reverse_merge!(null: false)

        t1_column, t2_column = [table_1, table_2].map{ |t| t.to_s.singularize.foreign_key }

        create_table(join_table_name, options.merge!(id: false)) do |td|
          td.integer t1_column, column_options
          td.integer t2_column, column_options
          yield td if block_given?
        end
      end

      def drop_join_table(table_1, table_2, options = {})
        join_table_name = find_join_table_name(table_1, table_2, options)
        drop_table(join_table_name)
      end

      def change_table(table_name, options = {})
        if supports_bulk_alter? && options[:bulk]
          recorder = ActiveRecord::Migration::CommandRecorder.new(self)
          yield update_table_definition(table_name, recorder)
          bulk_change_table(table_name, recorder.commands)
        else
          yield update_table_definition(table_name, self)
        end
      end

      def rename_table(table_name, new_name)
        raise NotImplementedError, "rename_table is not implemented"
      end

      def drop_table(table_name, options = {})
        execute "DROP TABLE #{quote_table_name(table_name)}"
      end

      def add_column(table_name, column_name, type, options = {})
        at = create_alter_table table_name
        at.add_column(column_name, type, options)
        execute schema_creation.accept at
      end

      def remove_columns(table_name, *column_names)
        raise ArgumentError.new("You must specify at least one column name. Example: remove_columns(:people, :first_name)") if column_names.empty?
        column_names.each do |column_name|
          remove_column(table_name, column_name)
        end
      end

      def remove_column(table_name, column_name, type = nil, options = {})
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP #{quote_column_name(column_name)}"
      end

      def change_column(table_name, column_name, type, options = {})
        raise NotImplementedError, "change_column is not implemented"
      end

      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
      end

      def change_column_null(table_name, column_name, null, default = nil)
        raise NotImplementedError, "change_column_null is not implemented"
      end

      def rename_column(table_name, column_name, new_column_name)
        raise NotImplementedError, "rename_column is not implemented"
      end

      def add_index(table_name, column_name, options = {})
        index_name, index_type, index_columns, index_options = add_index_options(table_name, column_name, options)
        execute "CREATE #{index_type} INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} (#{index_columns})#{index_options}"
      end

      def remove_index(table_name, options = {})
        remove_index!(table_name, index_name_for_remove(table_name, options))
      end

      def remove_index!(table_name, index_name) #:nodoc:
        execute "DROP INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)}"
      end

      def rename_index(table_name, old_name, new_name)
        validate_index_length!(table_name, new_name)

        old_index_def = indexes(table_name).detect { |i| i.name == old_name }
        return unless old_index_def
        add_index(table_name, old_index_def.columns, name: new_name, unique: old_index_def.unique)
        remove_index(table_name, name: old_name)
      end

      def index_name(table_name, options) #:nodoc:
        if Hash === options
          if options[:column]
            "index_#{table_name}_on_#{Array(options[:column]) * '_and_'}"
          elsif options[:name]
            options[:name]
          else
            raise ArgumentError, "You must specify the index name"
          end
        else
          index_name(table_name, :column => options)
        end
      end

      def index_name_exists?(table_name, index_name, default)
        return default unless respond_to?(:indexes)
        index_name = index_name.to_s
        indexes(table_name).detect { |i| i.name == index_name }
      end

      def add_reference(table_name, ref_name, options = {})
        polymorphic = options.delete(:polymorphic)
        index_options = options.delete(:index)
        type = options.delete(:type) || :integer
        foreign_key_options = options.delete(:foreign_key)

        if polymorphic && foreign_key_options
          raise ArgumentError, "Cannot add a foreign key to a polymorphic relation"
        end

        add_column(table_name, "#{ref_name}_id", type, options)
        add_column(table_name, "#{ref_name}_type", :string, polymorphic.is_a?(Hash) ? polymorphic : options) if polymorphic
        add_index(table_name, polymorphic ? %w[type id].map{ |t| "#{ref_name}_#{t}" } : "#{ref_name}_id", index_options.is_a?(Hash) ? index_options : {}) if index_options
        if foreign_key_options
          to_table = Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
          add_foreign_key(table_name, to_table, foreign_key_options.is_a?(Hash) ? foreign_key_options : {})
        end
      end
      alias :add_belongs_to :add_reference

      def remove_reference(table_name, ref_name, options = {})
        if options[:foreign_key]
          to_table = Base.pluralize_table_names ? ref_name.to_s.pluralize : ref_name
          remove_foreign_key(table_name, to_table)
        end

        remove_column(table_name, "#{ref_name}_id")
        remove_column(table_name, "#{ref_name}_type") if options[:polymorphic]
      end
      alias :remove_belongs_to :remove_reference

      def foreign_keys(table_name)
        raise NotImplementedError, "foreign_keys is not implemented"
      end

      def add_foreign_key(from_table, to_table, options = {})
        return unless supports_foreign_keys?

        options[:column] ||= foreign_key_column_for(to_table)

        options = {
          column: options[:column],
          primary_key: options[:primary_key],
          name: foreign_key_name(from_table, options),
          on_delete: options[:on_delete],
          on_update: options[:on_update]
        }
        at = create_alter_table from_table
        at.add_foreign_key to_table, options

        execute schema_creation.accept(at)
      end

      def remove_foreign_key(from_table, options_or_to_table = {})
        return unless supports_foreign_keys?

        if options_or_to_table.is_a?(Hash)
          options = options_or_to_table
        else
          options = { column: foreign_key_column_for(options_or_to_table) }
        end

        fk_name_to_delete = options.fetch(:name) do
          fk_to_delete = foreign_keys(from_table).detect {|fk| fk.column == options[:column].to_s }

          if fk_to_delete
            fk_to_delete.name
          else
            raise ArgumentError, "Table '#{from_table}' has no foreign key on column '#{options[:column]}'"
          end
        end

        at = create_alter_table from_table
        at.drop_foreign_key fk_name_to_delete

        execute schema_creation.accept(at)
      end

      def foreign_key_column_for(table_name) # :nodoc:
        prefix = Base.table_name_prefix
        suffix = Base.table_name_suffix
        name = table_name.to_s =~ /#{prefix}(.+)#{suffix}/ ? $1 : table_name.to_s
        "#{name.singularize}_id"
      end

      def dump_schema_information #:nodoc:
        sm_table = ActiveRecord::Migrator.schema_migrations_table_name

        ActiveRecord::SchemaMigration.order('version').map { |sm|
          "INSERT INTO #{sm_table} (version) VALUES ('#{sm.version}');"
        }.join "\n\n"
      end

      def initialize_schema_migrations_table
        ActiveRecord::SchemaMigration.create_table
      end

      def assume_migrated_upto_version(version, migrations_paths = ActiveRecord::Migrator.migrations_paths)
        migrations_paths = Array(migrations_paths)
        version = version.to_i
        sm_table = quote_table_name(ActiveRecord::Migrator.schema_migrations_table_name)

        migrated = select_values("SELECT version FROM #{sm_table}").map { |v| v.to_i }
        paths = migrations_paths.map {|p| "#{p}/[0-9]*_*.rb" }
        versions = Dir[*paths].map do |filename|
          filename.split('/').last.split('_').first.to_i
        end

        unless migrated.include?(version)
          execute "INSERT INTO #{sm_table} (version) VALUES ('#{version}')"
        end

        inserted = Set.new
        (versions - migrated).each do |v|
          if inserted.include?(v)
            raise "Duplicate migration #{v}. Please renumber your migrations to resolve the conflict."
          elsif v < version
            execute "INSERT INTO #{sm_table} (version) VALUES ('#{v}')"
            inserted << v
          end
        end
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        if native = native_database_types[type.to_sym]
          column_type_sql = (native.is_a?(Hash) ? native[:name] : native).dup

          if type == :decimal # ignore limit, use precision and scale
            scale ||= native[:scale]

            if precision ||= native[:precision]
              if scale
                column_type_sql << "(#{precision},#{scale})"
              else
                column_type_sql << "(#{precision})"
              end
            elsif scale
              raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale is specified"
            end

          elsif (type != :primary_key) && (limit ||= native.is_a?(Hash) && native[:limit])
            column_type_sql << "(#{limit})"
          end

          column_type_sql
        else
          type.to_s
        end
      end

      def columns_for_distinct(columns, orders) #:nodoc:
        columns
      end

      include TimestampDefaultDeprecation
      def add_timestamps(table_name, options = {})
        emit_warning_if_null_unspecified(:add_timestamps, options)
        add_column table_name, :created_at, :datetime, options
        add_column table_name, :updated_at, :datetime, options
      end

      def remove_timestamps(table_name, options = {})
        remove_column table_name, :updated_at
        remove_column table_name, :created_at
      end

      def update_table_definition(table_name, base) #:nodoc:
        Table.new(table_name, base)
      end

      def add_index_options(table_name, column_name, options = {}) #:nodoc:
        column_names = Array(column_name)
        index_name   = index_name(table_name, column: column_names)

        options.assert_valid_keys(:unique, :order, :name, :where, :length, :internal, :using, :algorithm, :type)

        index_type = options[:unique] ? "UNIQUE" : ""
        index_type = options[:type].to_s if options.key?(:type)
        index_name = options[:name].to_s if options.key?(:name)
        max_index_length = options.fetch(:internal, false) ? index_name_length : allowed_index_name_length

        if options.key?(:algorithm)
          algorithm = index_algorithms.fetch(options[:algorithm]) {
            raise ArgumentError.new("Algorithm must be one of the following: #{index_algorithms.keys.map(&:inspect).join(', ')}")
          }
        end

        using = "USING #{options[:using]}" if options[:using].present?

        if supports_partial_index?
          index_options = options[:where] ? " WHERE #{options[:where]}" : ""
        end

        if index_name.length > max_index_length
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' is too long; the limit is #{max_index_length} characters"
        end
        if table_exists?(table_name) && index_name_exists?(table_name, index_name, false)
          raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' already exists"
        end
        index_columns = quoted_columns_for_index(column_names, options).join(", ")

        [index_name, index_type, index_columns, index_options, algorithm, using]
      end

      protected
        def add_index_sort_order(option_strings, column_names, options = {})
          if options.is_a?(Hash) && order = options[:order]
            case order
            when Hash
              column_names.each {|name| option_strings[name] += " #{order[name].upcase}" if order.has_key?(name)}
            when String
              column_names.each {|name| option_strings[name] += " #{order.upcase}"}
            end
          end

          return option_strings
        end

        def quoted_columns_for_index(column_names, options = {})
          option_strings = Hash[column_names.map {|name| [name, '']}]

          if supports_index_sort_order?
            option_strings = add_index_sort_order(option_strings, column_names, options)
          end

          column_names.map {|name| quote_column_name(name) + option_strings[name]}
        end

        def options_include_default?(options)
          options.include?(:default) && !(options[:null] == false && options[:default].nil?)
        end

        def index_name_for_remove(table_name, options = {})
          index_name = index_name(table_name, options)

          unless index_name_exists?(table_name, index_name, true)
            if options.is_a?(Hash) && options.has_key?(:name)
              options_without_column = options.dup
              options_without_column.delete :column
              index_name_without_column = index_name(table_name, options_without_column)

              return index_name_without_column if index_name_exists?(table_name, index_name_without_column, false)
            end

            raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
          end

          index_name
        end

        def rename_table_indexes(table_name, new_name)
          indexes(new_name).each do |index|
            generated_index_name = index_name(table_name, column: index.columns)
            if generated_index_name == index.name
              rename_index new_name, generated_index_name, index_name(new_name, column: index.columns)
            end
          end
        end

        def rename_column_indexes(table_name, column_name, new_column_name)
          column_name, new_column_name = column_name.to_s, new_column_name.to_s
          indexes(table_name).each do |index|
            next unless index.columns.include?(new_column_name)
            old_columns = index.columns.dup
            old_columns[old_columns.index(new_column_name)] = column_name
            generated_index_name = index_name(table_name, column: old_columns)
            if generated_index_name == index.name
              rename_index table_name, generated_index_name, index_name(table_name, column: index.columns)
            end
          end
        end

      private
      def create_table_definition(name, temporary, options, as = nil)
        TableDefinition.new native_database_types, name, temporary, options, as
      end

      def create_alter_table(name)
        AlterTable.new create_table_definition(name, false, {})
      end

      def foreign_key_name(table_name, options) # :nodoc:
        identifier = "#{table_name}_#{options.fetch(:column)}_fk"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)
        options.fetch(:name) do
          "fk_rails_#{hashed_identifier}"
        end
      end

      def validate_index_length!(table_name, new_name)
        if new_name.length > allowed_index_name_length
          raise ArgumentError, "Index name '#{new_name}' on table '#{table_name}' is too long; the limit is #{allowed_index_name_length} characters"
        end
      end
    end
  end
end
