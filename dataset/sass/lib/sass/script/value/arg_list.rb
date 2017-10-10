module Sass::Script::Value
  class ArgList < List
    attr_accessor :keywords_accessed

    def initialize(value, keywords, separator)
      super(value, separator)
      if keywords.is_a?(Sass::Util::NormalizedMap)
        @keywords = keywords
      else
        @keywords = Sass::Util::NormalizedMap.new(keywords)
      end
    end

    def keywords
      @keywords_accessed = true
      @keywords
    end
  end
end
