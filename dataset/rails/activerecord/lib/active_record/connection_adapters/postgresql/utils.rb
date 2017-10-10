module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class Name # :nodoc:
        SEPARATOR = "."
        attr_reader :schema, :identifier

        def initialize(schema, identifier)
          @schema, @identifier = unquote(schema), unquote(identifier)
        end

        def to_s
          parts.join SEPARATOR
        end

        def quoted
          if schema
            PGconn.quote_ident(schema) << SEPARATOR << PGconn.quote_ident(identifier)
          else
            PGconn.quote_ident(identifier)
          end
        end

        def ==(o)
          o.class == self.class && o.parts == parts
        end
        alias_method :eql?, :==

        def hash
          parts.hash
        end

        protected
          def unquote(part)
            if part && part.start_with?('"')
              part[1..-2]
            else
              part
            end
          end

          def parts
            @parts ||= [@schema, @identifier].compact
          end
      end

      module Utils # :nodoc:
        extend self

        def extract_schema_qualified_name(string)
          schema, table = string.scan(/[^".\s]+|"[^"]*"/)
          if table.nil?
            table = schema
            schema = nil
          end
          PostgreSQL::Name.new(schema, table)
        end
      end
    end
  end
end
