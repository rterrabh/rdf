module ActiveRecord
  module Batches
    def find_each(options = {})
      if block_given?
        find_in_batches(options) do |records|
          records.each { |record| yield record }
        end
      else
        enum_for :find_each, options do
          options[:start] ? where(table[primary_key].gteq(options[:start])).size : size
        end
      end
    end

    def find_in_batches(options = {})
      options.assert_valid_keys(:start, :batch_size)

      relation = self
      start = options[:start]
      batch_size = options[:batch_size] || 1000

      unless block_given?
        return to_enum(:find_in_batches, options) do
          total = start ? where(table[primary_key].gteq(start)).size : size
          (total - 1).div(batch_size) + 1
        end
      end

      if logger && (arel.orders.present? || arel.taken.present?)
        logger.warn("Scoped order and limit are ignored, it's forced to be batch order and batch size")
      end

      relation = relation.reorder(batch_order).limit(batch_size)
      records = start ? relation.where(table[primary_key].gteq(start)).to_a : relation.to_a

      while records.any?
        records_size = records.size
        primary_key_offset = records.last.id
        raise "Primary key not included in the custom select clause" unless primary_key_offset

        yield records

        break if records_size < batch_size

        records = relation.where(table[primary_key].gt(primary_key_offset)).to_a
      end
    end

    private

    def batch_order
      "#{quoted_table_name}.#{quoted_primary_key} ASC"
    end
  end
end
