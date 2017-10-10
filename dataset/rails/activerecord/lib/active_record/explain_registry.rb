require 'active_support/per_thread_registry'

module ActiveRecord
  class ExplainRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :queries, :collect

    def initialize
      reset
    end

    def collect?
      @collect
    end

    def reset
      @collect = false
      @queries = []
    end
  end
end
