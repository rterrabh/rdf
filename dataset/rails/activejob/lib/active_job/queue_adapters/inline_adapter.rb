module ActiveJob
  module QueueAdapters
    class InlineAdapter
      class << self
        def enqueue(job) #:nodoc:
          Base.execute(job.serialize)
        end

        def enqueue_at(*) #:nodoc:
          raise NotImplementedError.new("Use a queueing backend to enqueue jobs in the future. Read more at http://guides.rubyonrails.org/active_job_basics.html")
        end
      end
    end
  end
end
