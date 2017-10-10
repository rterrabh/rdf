module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        def xml(*args)
          options = args.extract_options!
          column(args[0], :xml, options)
        end

        def tsvector(*args)
          options = args.extract_options!
          column(args[0], :tsvector, options)
        end

        def int4range(name, options = {})
          column(name, :int4range, options)
        end

        def int8range(name, options = {})
          column(name, :int8range, options)
        end

        def tsrange(name, options = {})
          column(name, :tsrange, options)
        end

        def tstzrange(name, options = {})
          column(name, :tstzrange, options)
        end

        def numrange(name, options = {})
          column(name, :numrange, options)
        end

        def daterange(name, options = {})
          column(name, :daterange, options)
        end

        def hstore(name, options = {})
          column(name, :hstore, options)
        end

        def ltree(name, options = {})
          column(name, :ltree, options)
        end

        def inet(name, options = {})
          column(name, :inet, options)
        end

        def cidr(name, options = {})
          column(name, :cidr, options)
        end

        def macaddr(name, options = {})
          column(name, :macaddr, options)
        end

        def uuid(name, options = {})
          column(name, :uuid, options)
        end

        def json(name, options = {})
          column(name, :json, options)
        end

        def jsonb(name, options = {})
          column(name, :jsonb, options)
        end

        def citext(name, options = {})
          column(name, :citext, options)
        end

        def point(name, options = {})
          column(name, :point, options)
        end

        def bit(name, options = {})
          column(name, :bit, options)
        end

        def bit_varying(name, options = {})
          column(name, :bit_varying, options)
        end

        def money(name, options = {})
          column(name, :money, options)
        end
      end

      class ColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
        attr_accessor :array
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        def primary_key(name, type = :primary_key, options = {})
          return super unless type == :uuid
          options[:default] = options.fetch(:default, 'uuid_generate_v4()')
          options[:primary_key] = true
          column name, type, options
        end

        def new_column_definition(name, type, options) # :nodoc:
          column = super
          column.array = options[:array]
          column
        end

        private

          def create_column_definition(name, type)
            PostgreSQL::ColumnDefinition.new name, type
          end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
