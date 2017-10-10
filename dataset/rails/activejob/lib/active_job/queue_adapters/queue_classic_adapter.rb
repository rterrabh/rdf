require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def enqueue(job) #:nodoc:
          build_queue(job.queue_name).enqueue("#{JobWrapper.name}.perform", job.serialize)
        end

        def enqueue_at(job, timestamp) #:nodoc:
          queue = build_queue(job.queue_name)
          unless queue.respond_to?(:enqueue_at)
            raise NotImplementedError, 'To be able to schedule jobs with queue_classic ' \
              'the QC::Queue needs to respond to `enqueue_at(timestamp, method, *args)`. ' \
              'You can implement this yourself or you can use the queue_classic-later gem.'
          end
          queue.enqueue_at(timestamp, "#{JobWrapper.name}.perform", job.serialize)
        end

        def build_queue(queue_name)
          QC::Queue.new(queue_name)
        end
      end

      class JobWrapper #:nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
