
module Homebrew
  module Hooks
    module Bottles
      def self.setup_formula_has_bottle(&block)
        @has_bottle = block
        true
      end

      def self.setup_pour_formula_bottle(&block)
        @pour_bottle = block
        true
      end

      def self.formula_has_bottle?(formula)
        return false unless @has_bottle
        @has_bottle.call formula
      end

      def self.pour_formula_bottle(formula)
        return false unless @pour_bottle
        @pour_bottle.call formula
      end

      def self.reset_hooks
        @has_bottle = @pour_bottle = nil
      end
    end
  end
end
