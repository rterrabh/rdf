require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_record/relation/merger'

module ActiveRecord
  module SpawnMethods

    def spawn #:nodoc:
      clone
    end

    def merge(other)
      if other.is_a?(Array)
        to_a & other
      elsif other
        spawn.merge!(other)
      else
        self
      end
    end

    def merge!(other) # :nodoc:
      if !other.is_a?(Relation) && other.respond_to?(:to_proc)
        #nodyna <instance_exec-834> <IEX COMPLEX (block without parameters)>
        instance_exec(&other)
      else
        klass = other.is_a?(Hash) ? Relation::HashMerger : Relation::Merger
        klass.new(self, other).merge
      end
    end

    def except(*skips)
      relation_with values.except(*skips)
    end

    def only(*onlies)
      if onlies.any? { |o| o == :where }
        onlies << :bind
      end
      relation_with values.slice(*onlies)
    end

    private

      def relation_with(values) # :nodoc:
        result = Relation.create(klass, table, values)
        result.extend(*extending_values) if extending_values.any?
        result
      end
  end
end
