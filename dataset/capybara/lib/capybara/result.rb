require 'forwardable'

module Capybara

  class Result
    include Enumerable
    extend Forwardable

    def initialize(elements, query)
      @elements = elements
      @result = elements.select { |node| query.matches_filters?(node) }
      @rest = @elements - @result
      @query = query
    end

    def_delegators :@result, :each, :[], :at, :size, :count, :length,
                   :first, :last, :values_at, :empty?, :inspect, :sample, :index

    def matches_count?
      Capybara::Helpers.matches_count?(@result.size, @query.options)
    end

    def failure_message
      message = Capybara::Helpers.failure_message(@query.description, @query.options)
      if count > 0
        message << ", found #{count} #{Capybara::Helpers.declension("match", "matches", count)}: " << @result.map(&:text).map(&:inspect).join(", ")
      else
        message << " but there were no matches"
      end
      unless @rest.empty?
        elements = @rest.map(&:text).map(&:inspect).join(", ")
        message << ". Also found " << elements << ", which matched the selector but not all filters."
      end
      message
    end

    def negative_failure_message
      failure_message.sub(/(to find)/, 'not \1')
    end
  end
end
