module Sass::Tree
  class SupportsNode < DirectiveNode
    attr_accessor :name

    attr_accessor :condition

    def initialize(name, condition)
      @name = name
      @condition = condition
      super('')
    end

    def value; raise NotImplementedError; end

    def resolved_value
      @resolved_value ||= "@#{name} #{condition.to_css}"
    end

    def invisible?
      children.all? {|c| c.invisible?}
    end
  end
end
