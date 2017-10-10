module Sass::Tree
  class MediaNode < DirectiveNode

    attr_accessor :query

    attr_accessor :resolved_query

    def initialize(query)
      @query = query
      super('')
    end

    def value; raise NotImplementedError; end

    def name; '@media'; end

    def resolved_value
      @resolved_value ||= "@media #{resolved_query.to_css}"
    end

    def invisible?
      children.all? {|c| c.invisible?}
    end
  end
end
