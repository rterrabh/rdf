require 'active_support/rescuable'
require 'active_job/arguments'

module ActiveJob
  module Execution
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    module ClassMethods
      def perform_now(*args)
        job_or_instantiate(*args).perform_now
      end

      def execute(job_data) #:nodoc:
        job = deserialize(job_data)
        job.perform_now
      end
    end

    def perform_now
      deserialize_arguments_if_needed
      run_callbacks :perform do
        perform(*arguments)
      end
    rescue => exception
      rescue_with_handler(exception) || raise(exception)
    end

    def perform(*)
      fail NotImplementedError
    end
  end
end
