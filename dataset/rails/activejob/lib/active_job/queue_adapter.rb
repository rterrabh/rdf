require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  module QueueAdapter #:nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
      mattr_reader(:queue_adapter) { ActiveJob::QueueAdapters::InlineAdapter }

      def queue_adapter=(name_or_adapter)
        @@queue_adapter = \
          case name_or_adapter
          when :test
            ActiveJob::QueueAdapters::TestAdapter.new
          when Symbol, String
            load_adapter(name_or_adapter)
          else
            name_or_adapter if name_or_adapter.respond_to?(:enqueue)
          end
      end

      private
        def load_adapter(name)
          "ActiveJob::QueueAdapters::#{name.to_s.camelize}Adapter".constantize
        end
    end
  end
end
