require 'active_support/core_ext/hash/indifferent_access'

module ActiveRecord
  module Inheritance
    extend ActiveSupport::Concern

    included do
      class_attribute :store_full_sti_class, instance_writer: false
      self.store_full_sti_class = true
    end

    module ClassMethods
      def new(*args, &block)
        if abstract_class? || self == Base
          raise NotImplementedError, "#{self} is an abstract class and cannot be instantiated."
        end

        attrs = args.first
        if subclass_from_attributes?(attrs)
          subclass = subclass_from_attributes(attrs)
        end

        if subclass
          subclass.new(*args, &block)
        else
          super
        end
      end

      def descends_from_active_record?
        if self == Base
          false
        elsif superclass.abstract_class?
          superclass.descends_from_active_record?
        else
          superclass == Base || !columns_hash.include?(inheritance_column)
        end
      end

      def finder_needs_type_condition? #:nodoc:
        :true == (@finder_needs_type_condition ||= descends_from_active_record? ? :false : :true)
      end

      def symbolized_base_class
        ActiveSupport::Deprecation.warn('`ActiveRecord::Base.symbolized_base_class` is deprecated and will be removed without replacement.')
        @symbolized_base_class ||= base_class.to_s.to_sym
      end

      def symbolized_sti_name
        ActiveSupport::Deprecation.warn('`ActiveRecord::Base.symbolized_sti_name` is deprecated and will be removed without replacement.')
        @symbolized_sti_name ||= sti_name.present? ? sti_name.to_sym : symbolized_base_class
      end

      def base_class
        unless self < Base
          raise ActiveRecordError, "#{name} doesn't belong in a hierarchy descending from ActiveRecord"
        end

        if superclass == Base || superclass.abstract_class?
          self
        else
          superclass.base_class
        end
      end

      attr_accessor :abstract_class

      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def sti_name
        store_full_sti_class ? name : name.demodulize
      end

      protected

      def compute_type(type_name)
        if type_name.match(/^::/)
          ActiveSupport::Dependencies.constantize(type_name)
        else
          candidates = []
          name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
          candidates << type_name

          candidates.each do |candidate|
            constant = ActiveSupport::Dependencies.safe_constantize(candidate)
            return constant if candidate == constant.to_s
          end

          raise NameError.new("uninitialized constant #{candidates.first}", candidates.first)
        end
      end

      private

      def discriminate_class_for_record(record)
        if using_single_table_inheritance?(record)
          find_sti_class(record[inheritance_column])
        else
          super
        end
      end

      def using_single_table_inheritance?(record)
        record[inheritance_column].present? && columns_hash.include?(inheritance_column)
      end

      def find_sti_class(type_name)
        if store_full_sti_class
          ActiveSupport::Dependencies.constantize(type_name)
        else
          compute_type(type_name)
        end
      rescue NameError
        raise SubclassNotFound,
          "The single-table inheritance mechanism failed to locate the subclass: '#{type_name}'. " +
          "This error is raised because the column '#{inheritance_column}' is reserved for storing the class in case of inheritance. " +
          "Please rename this column if you didn't intend it to be used for storing the inheritance class " +
          "or overwrite #{name}.inheritance_column to use another column for that information."
      end

      def type_condition(table = arel_table)
        sti_column = table[inheritance_column]
        sti_names  = ([self] + descendants).map { |model| model.sti_name }

        sti_column.in(sti_names)
      end

      def subclass_from_attributes?(attrs)
        columns_hash.include?(inheritance_column) && attrs.is_a?(Hash)
      end

      def subclass_from_attributes(attrs)
        subclass_name = attrs.with_indifferent_access[inheritance_column]

        if subclass_name.present? && subclass_name != self.name
          subclass = subclass_name.safe_constantize

          unless descendants.include?(subclass)
            raise ActiveRecord::SubclassNotFound.new("Invalid single-table inheritance type: #{subclass_name} is not a subclass of #{name}")
          end

          subclass
        end
      end
    end

    def initialize_dup(other)
      super
      ensure_proper_type
    end

    private

    def initialize_internals_callback
      super
      ensure_proper_type
    end

    def ensure_proper_type
      klass = self.class
      if klass.finder_needs_type_condition?
        write_attribute(klass.inheritance_column, klass.sti_name)
      end
    end
  end
end
