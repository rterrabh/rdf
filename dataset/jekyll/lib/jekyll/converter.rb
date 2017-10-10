module Jekyll
  class Converter < Plugin
    def self.highlighter_prefix(highlighter_prefix = nil)
      @highlighter_prefix = highlighter_prefix if highlighter_prefix
      @highlighter_prefix
    end

    def self.highlighter_suffix(highlighter_suffix = nil)
      @highlighter_suffix = highlighter_suffix if highlighter_suffix
      @highlighter_suffix
    end

    def initialize(config = {})
      @config = config
    end

    def highlighter_prefix
      self.class.highlighter_prefix
    end

    def highlighter_suffix
      self.class.highlighter_suffix
    end
  end
end
