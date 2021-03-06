module ActiveRecord
  class Migration
    class CommandRecorder
      include JoinTable

      attr_accessor :commands, :delegate, :reverting

      def initialize(delegate = nil)
        @commands = []
        @delegate = delegate
        @reverting = false
      end

      def revert
        @reverting = !@reverting
        previous = @commands
        @commands = []
        yield
      ensure
        @commands = previous.concat(@commands.reverse)
        @reverting = !@reverting
      end

      def record(*command, &block)
        if @reverting
          @commands << inverse_of(*command, &block)
        else
          @commands << (command << block)
        end
      end

      def inverse_of(command, args, &block)
        method = :"invert_#{command}"
        raise IrreversibleMigration unless respond_to?(method, true)
        #nodyna <send-768> <SD COMPLEX (change-prone variables)>
        send(method, args, &block)
      end

      def respond_to?(*args) # :nodoc:
        super || delegate.respond_to?(*args)
      end

      [:create_table, :create_join_table, :rename_table, :add_column, :remove_column,
        :rename_index, :rename_column, :add_index, :remove_index, :add_timestamps, :remove_timestamps,
        :change_column_default, :add_reference, :remove_reference, :transaction,
        :drop_join_table, :drop_table, :execute_block, :enable_extension,
        :change_column, :execute, :remove_columns, :change_column_null,
        :add_foreign_key, :remove_foreign_key
      ].each do |method|
        #nodyna <class_eval-769> <CE MODERATE (define methods)>
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)          # def create_table(*args, &block)
            record(:"#{method}", args, &block)  #   record(:create_table, args, &block)
          end                                   # end
        EOV
      end
      alias :add_belongs_to :add_reference
      alias :remove_belongs_to :remove_reference

      def change_table(table_name, options = {}) # :nodoc:
        yield delegate.update_table_definition(table_name, self)
      end

      private

      module StraightReversions
        private
        { transaction:       :transaction,
          execute_block:     :execute_block,
          create_table:      :drop_table,
          create_join_table: :drop_join_table,
          add_column:        :remove_column,
          add_timestamps:    :remove_timestamps,
          add_reference:     :remove_reference,
          enable_extension:  :disable_extension
        }.each do |cmd, inv|
          [[inv, cmd], [cmd, inv]].uniq.each do |method, inverse|
            #nodyna <class_eval-770> <CE MODERATE (define methods)>
            class_eval <<-EOV, __FILE__, __LINE__ + 1
              def invert_#{method}(args, &block)    # def invert_create_table(args, &block)
                [:#{inverse}, args, block]          #   [:drop_table, args, block]
              end                                   # end
            EOV
          end
        end
      end

      include StraightReversions

      def invert_drop_table(args, &block)
        if args.size == 1 && block == nil
          raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty)."
        end
        super
      end

      def invert_rename_table(args)
        [:rename_table, args.reverse]
      end

      def invert_remove_column(args)
        raise ActiveRecord::IrreversibleMigration, "remove_column is only reversible if given a type." if args.size <= 2
        super
      end

      def invert_rename_index(args)
        [:rename_index, [args.first] + args.last(2).reverse]
      end

      def invert_rename_column(args)
        [:rename_column, [args.first] + args.last(2).reverse]
      end

      def invert_add_index(args)
        table, columns, options = *args
        options ||= {}

        index_name = options[:name]
        options_hash = index_name ? { name: index_name } : { column: columns }

        [:remove_index, [table, options_hash]]
      end

      def invert_remove_index(args)
        table, options = *args

        unless options && options.is_a?(Hash) && options[:column]
          raise ActiveRecord::IrreversibleMigration, "remove_index is only reversible if given a :column option."
        end

        options = options.dup
        [:add_index, [table, options.delete(:column), options]]
      end

      alias :invert_add_belongs_to :invert_add_reference
      alias :invert_remove_belongs_to :invert_remove_reference

      def invert_change_column_null(args)
        args[2] = !args[2]
        [:change_column_null, args]
      end

      def invert_add_foreign_key(args)
        from_table, to_table, add_options = args
        add_options ||= {}

        if add_options[:name]
          options = { name: add_options[:name] }
        elsif add_options[:column]
          options = { column: add_options[:column] }
        else
          options = to_table
        end

        [:remove_foreign_key, [from_table, options]]
      end

      def method_missing(method, *args, &block)
        if @delegate.respond_to?(method)
          #nodyna <send-771> <SD COMPLEX (change-prone variables)>
          @delegate.send(method, *args, &block)
        else
          super
        end
      end
    end
  end
end
