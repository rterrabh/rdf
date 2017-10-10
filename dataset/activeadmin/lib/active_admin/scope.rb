module ActiveAdmin
  class Scope

    attr_reader :scope_method, :id, :scope_block, :display_if_block, :show_count, :default_block

    def initialize(name, method = nil, options = {}, &block)
      @name, @scope_method = name, method.try(:to_sym)

      if name.is_a? Proc
        raise "A string/symbol is required as the second argument if your label is a proc." unless method
        @id = method.to_s.parameterize("_")
      else
        @scope_method ||= name.to_sym
        @id = name.to_s.parameterize("_")
      end

      @scope_method               = nil        if @scope_method == :all
      @scope_method, @scope_block = nil, block if block_given?

      @show_count       = options.fetch(:show_count, true)
      @display_if_block = options[:if]      || proc{ true }
      @default_block    = options[:default] || proc{ false }

    end

    def name
      case @name
        when Proc   then @name.call.to_s
        when String then @name
        when Symbol then @name.to_s.titleize
        else             @name.to_s
      end
    end

  end
end
