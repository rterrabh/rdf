require 'active_job/arguments'

module ActiveJob
  module Enqueuing
    extend ActiveSupport::Concern

    module ClassMethods
      def perform_later(*args)
        job_or_instantiate(*args).enqueue
      end

      protected
        def job_or_instantiate(*args)
          args.first.is_a?(self) ? args.first : new(*args)
        end
    end

    def retry_job(options={})
      enqueue options
    end

    def enqueue(options={})
      self.scheduled_at = options[:wait].seconds.from_now.to_f if options[:wait]
      self.scheduled_at = options[:wait_until].to_f if options[:wait_until]
      self.queue_name   = self.class.queue_name_from_part(options[:queue]) if options[:queue]
      run_callbacks :enqueue do
        if self.scheduled_at
          self.class.queue_adapter.enqueue_at self, self.scheduled_at
        else
          self.class.queue_adapter.enqueue self
        end
      end
      self
    end
  end
end
