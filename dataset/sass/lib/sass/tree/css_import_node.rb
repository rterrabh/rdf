module Sass::Tree
  class CssImportNode < DirectiveNode
    attr_accessor :uri

    attr_accessor :resolved_uri

    attr_accessor :query

    attr_accessor :resolved_query

    def initialize(uri, query = [])
      @uri = uri
      @query = query
      super('')
    end

    def self.resolved(uri)
      node = new(uri)
      node.resolved_uri = uri
      node
    end

    def value; raise NotImplementedError; end

    def resolved_value
      @resolved_value ||=
        begin
          str = "@import #{resolved_uri}"
          str << " #{resolved_query.to_css}" if resolved_query
          str
        end
    end
  end
end
