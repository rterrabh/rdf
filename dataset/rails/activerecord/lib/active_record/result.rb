module ActiveRecord
  class Result
    include Enumerable

    IDENTITY_TYPE = Type::Value.new # :nodoc:

    attr_reader :columns, :rows, :column_types

    def initialize(columns, rows, column_types = {})
      @columns      = columns
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types
    end

    def length
      @rows.length
    end

    def each
      if block_given?
        hash_rows.each { |row| yield row }
      else
        hash_rows.to_enum { @rows.size }
      end
    end

    def to_hash
      hash_rows
    end

    alias :map! :map
    alias :collect! :map

    def empty?
      rows.empty?
    end

    def to_ary
      hash_rows
    end

    def [](idx)
      hash_rows[idx]
    end

    def last
      hash_rows.last
    end

    def cast_values(type_overrides = {}) # :nodoc:
      types = columns.map { |name| column_type(name, type_overrides) }
      result = rows.map do |values|
        types.zip(values).map { |type, value| type.type_cast_from_database(value) }
      end

      columns.one? ? result.map!(&:first) : result
    end

    def initialize_copy(other)
      @columns      = columns.dup
      @rows         = rows.dup
      @column_types = column_types.dup
      @hash_rows    = nil
    end

    private

    def column_type(name, type_overrides = {})
      type_overrides.fetch(name) do
        column_types.fetch(name, IDENTITY_TYPE)
      end
    end

    def hash_rows
      @hash_rows ||=
        begin
          columns = @columns.map { |c| c.dup.freeze }
          @rows.map { |row|
            hash = {}

            index = 0
            length = columns.length

            while index < length
              hash[columns[index]] = row[index]
              index += 1
            end

            hash
          }
        end
    end
  end
end
