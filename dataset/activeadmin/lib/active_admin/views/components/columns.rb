module ActiveAdmin
  module Views

    class Columns < ActiveAdmin::Component
      builder_method :columns

      def column(*args, &block)
        insert_tag Column, *args, &block
      end

      def add_child(*)
        super
        calculate_columns!
      end

      protected

      def closing_tag
        "<div style=\"clear:both;\"></div>" + super
      end

      def margin_size
        2
      end

      def calculate_columns!
        span_count = columns_span_count
        columns_count = children.size

        all_margins_width = margin_size * (span_count - 1)
        column_width = (100.00 - all_margins_width) / span_count

        children.each_with_index do |col, i|
          is_last_column = i == (columns_count - 1)
          col.set_column_styles(column_width, margin_size, is_last_column)
        end
      end

      def columns_span_count
        count = 0
        children.each {|column| count += column.span_size }

        count
      end

    end

    class Column < ActiveAdmin::Component

      attr_accessor :span_size, :max_width, :min_width

      def build(options = {})
        options = options.dup
        @span_size = options.delete(:span) || 1
        @max_width = options.delete(:max_width)
        @min_width = options.delete(:min_width)

        super(options)
      end

      def set_column_styles(column_width, margin_width, is_last_column = false)
        column_with_span_width = (span_size * column_width) + ((span_size - 1) * margin_width)

        styles = []

        styles << "width: #{column_with_span_width}%;"

        if max_width
          styles << "max-width: #{safe_width(max_width)};"
        end

        if min_width
          styles << "min-width: #{safe_width(min_width)};"
        end

        styles << "margin-right: #{margin_width}%;" unless is_last_column

        set_attribute :style, styles.join(" ")
      end

      private

      def safe_width(width)
        width.to_s.gsub(/\A(\d+)\z/, '\1px')
      end

    end
  end
end
