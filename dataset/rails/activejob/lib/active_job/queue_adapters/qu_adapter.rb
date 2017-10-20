require 'qu'

module ActiveJob
  module QueueAdapters
    class QuAdapter
      class << self
        def enqueue(job, *args) #:nodoc:
          Qu::Payload.new(klass: JobWrapper, args: [job.serialize]).tap do |payload|
            #nodyna <instance_variable_set-1328> <IVS COMPLEX (private access)>
            payload.instance_variable_set(:@queue, job.queue_name)
          end.push
        end

        def enqueue_at(job, timestamp, *args) #:nodoc:
          raise NotImplementedError
        end
      end

      class JobWrapper < Qu::Job #:nodoc:
        def initialize(job_data)
          @job_data  = job_data
        end

        def perform
          Base.execute @job_data
        end
      end
    end
  end
end
