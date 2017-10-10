module ActiveAdmin

  class PagePresenter

    attr_reader :block, :options

    delegate :has_key?, :fetch, to: :options

    def initialize(options = {}, &block)
      @options, @block = options, block
    end

    def [](key)
      @options[key]
    end

  end
end
