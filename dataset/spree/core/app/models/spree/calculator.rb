module Spree
  class Calculator < Spree::Base
    if connection.table_exists?(:spree_calculators) && connection.column_exists?(:spree_calculators, :deleted_at)
      acts_as_paranoid
    end

    belongs_to :calculable, polymorphic: true

    def compute(computable)
      computable_name = computable.class.name.demodulize.underscore
      method = "compute_#{computable_name}".to_sym
      calculator_class = self.class
      if respond_to?(method)
        #nodyna <send-2504> <SD COMPLEX (change-prone variables)>
        self.send(method, computable)
      else
        raise NotImplementedError, "Please implement '#{method}(#{computable_name})' in your calculator: #{calculator_class.name}"
      end
    end

    def self.description
      'Base Calculator'
    end


    def self.register(*klasses)
    end

    def self.calculators
      Rails.application.config.spree.calculators
    end

    def to_s
      self.class.name.titleize.gsub("Calculator\/", "")
    end

    def description
      self.class.description
    end

    def available?(object)
      true
    end
  end
end
