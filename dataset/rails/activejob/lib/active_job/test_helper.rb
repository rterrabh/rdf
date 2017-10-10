require 'active_support/core_ext/hash/keys'

module ActiveJob
  module TestHelper
    extend ActiveSupport::Concern

    included do
      def before_setup
        @old_queue_adapter  = queue_adapter
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
        clear_performed_jobs
        super
      end

      def after_teardown
        super
        ActiveJob::Base.queue_adapter = @old_queue_adapter
      end

      def assert_enqueued_jobs(number)
        if block_given?
          original_count = enqueued_jobs.size
          yield
          new_count = enqueued_jobs.size
          assert_equal number, new_count - original_count,
                       "#{number} jobs expected, but #{new_count - original_count} were enqueued"
        else
          enqueued_jobs_size = enqueued_jobs.size
          assert_equal number, enqueued_jobs_size, "#{number} jobs expected, but #{enqueued_jobs_size} were enqueued"
        end
      end

      def assert_no_enqueued_jobs(&block)
        assert_enqueued_jobs 0, &block
      end

      def assert_performed_jobs(number)
        if block_given?
          original_count = performed_jobs.size
          perform_enqueued_jobs { yield }
          new_count = performed_jobs.size
          assert_equal number, new_count - original_count,
                       "#{number} jobs expected, but #{new_count - original_count} were performed"
        else
          performed_jobs_size = performed_jobs.size
          assert_equal number, performed_jobs_size, "#{number} jobs expected, but #{performed_jobs_size} were performed"
        end
      end

      def assert_no_performed_jobs(&block)
        assert_performed_jobs 0, &block
      end

      def assert_enqueued_with(args = {}, &_block)
        original_enqueued_jobs = enqueued_jobs.dup
        clear_enqueued_jobs
        args.assert_valid_keys(:job, :args, :at, :queue)
        serialized_args = serialize_args_for_assertion(args)
        yield
        matching_job = enqueued_jobs.any? do |job|
          serialized_args.all? { |key, value| value == job[key] }
        end
        assert matching_job, "No enqueued job found with #{args}"
      ensure
        queue_adapter.enqueued_jobs = original_enqueued_jobs + enqueued_jobs
      end

      def assert_performed_with(args = {}, &_block)
        original_performed_jobs = performed_jobs.dup
        clear_performed_jobs
        args.assert_valid_keys(:job, :args, :at, :queue)
        serialized_args = serialize_args_for_assertion(args)
        perform_enqueued_jobs { yield }
        matching_job = performed_jobs.any? do |job|
          serialized_args.all? { |key, value| value == job[key] }
        end
        assert matching_job, "No performed job found with #{args}"
      ensure
        queue_adapter.performed_jobs = original_performed_jobs + performed_jobs
      end

      def perform_enqueued_jobs
        @old_perform_enqueued_jobs = queue_adapter.perform_enqueued_jobs
        @old_perform_enqueued_at_jobs = queue_adapter.perform_enqueued_at_jobs
        queue_adapter.perform_enqueued_jobs = true
        queue_adapter.perform_enqueued_at_jobs = true
        yield
      ensure
        queue_adapter.perform_enqueued_jobs = @old_perform_enqueued_jobs
        queue_adapter.perform_enqueued_at_jobs = @old_perform_enqueued_at_jobs
      end

      def queue_adapter
        ActiveJob::Base.queue_adapter
      end

      delegate :enqueued_jobs, :enqueued_jobs=,
               :performed_jobs, :performed_jobs=,
               to: :queue_adapter

      private
        def clear_enqueued_jobs
          enqueued_jobs.clear
        end

        def clear_performed_jobs
          performed_jobs.clear
        end

        def serialize_args_for_assertion(args)
          serialized_args = args.dup
          if job_args = serialized_args.delete(:args)
            serialized_args[:args] = ActiveJob::Arguments.serialize(job_args)
          end
          serialized_args
        end
    end
  end
end
