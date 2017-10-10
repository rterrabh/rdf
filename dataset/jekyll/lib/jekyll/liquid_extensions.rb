module Jekyll
  module LiquidExtensions

    def lookup_variable(context, variable)
      lookup = context

      variable.split(".").each do |value|
        lookup = lookup[value]
      end

      lookup || variable
    end

  end
end
