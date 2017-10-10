require 'active_support/lazy_load_hooks'
require 'active_record/explain_registry'

module ActiveRecord
  module Explain
    def collecting_queries_for_explain # :nodoc:
      ExplainRegistry.collect = true
      yield
      ExplainRegistry.queries
    ensure
      ExplainRegistry.reset
    end

    def exec_explain(queries) # :nodoc:
      str = queries.map do |sql, bind|
        [].tap do |msg|
          msg << "EXPLAIN for: #{sql}"
          unless bind.empty?
            bind_msg = bind.map {|col, val| [col.name, val]}.inspect
            msg.last << " #{bind_msg}"
          end
          msg << connection.explain(sql, bind)
        end.join("\n")
      end.join("\n")

      def str.inspect
        self
      end

      str
    end
  end
end
