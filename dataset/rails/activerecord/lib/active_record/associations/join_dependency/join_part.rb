module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      class JoinPart # :nodoc:
        include Enumerable

        attr_reader :base_klass, :children

        delegate :table_name, :column_names, :primary_key, :to => :base_klass

        def initialize(base_klass, children)
          @base_klass = base_klass
          @children = children
        end

        def name
          reflection.name
        end

        def match?(other)
          self.class == other.class
        end

        def each(&block)
          yield self
          children.each { |child| child.each(&block) }
        end

        def table
          raise NotImplementedError
        end

        def aliased_table_name
          raise NotImplementedError
        end

        def extract_record(row, column_names_with_alias)
          hash = {}

          index = 0
          length = column_names_with_alias.length

          while index < length
            column_name, alias_name = column_names_with_alias[index]
            hash[column_name] = row[alias_name]
            index += 1
          end

          hash
        end

        def instantiate(row, aliases)
          base_klass.instantiate(extract_record(row, aliases))
        end
      end
    end
  end
end
