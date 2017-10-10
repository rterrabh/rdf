module ActiveJob
  module Core
    extend ActiveSupport::Concern

    included do
      attr_accessor :arguments
      attr_writer :serialized_arguments

      attr_accessor :scheduled_at

      attr_accessor :job_id

      attr_writer :queue_name

      attr_accessor :locale
    end

    module ClassMethods
      def deserialize(job_data)
        job                      = job_data['job_class'].constantize.new
        job.job_id               = job_data['job_id']
        job.queue_name           = job_data['queue_name']
        job.serialized_arguments = job_data['arguments']
        job.locale               = job_data['locale'] || I18n.locale
        job
      end

      def set(options={})
        ConfiguredJob.new(self, options)
      end
    end

    def initialize(*arguments)
      @arguments  = arguments
      @job_id     = SecureRandom.uuid
      @queue_name = self.class.queue_name
    end

    def serialize
      {
        'job_class'  => self.class.name,
        'job_id'     => job_id,
        'queue_name' => queue_name,
        'arguments'  => serialize_arguments(arguments),
        'locale'     => I18n.locale
      }
    end

    private
      def deserialize_arguments_if_needed
        if defined?(@serialized_arguments) && @serialized_arguments.present?
          @arguments = deserialize_arguments(@serialized_arguments)
          @serialized_arguments = nil
        end
      end

      def serialize_arguments(serialized_args)
        Arguments.serialize(serialized_args)
      end

      def deserialize_arguments(serialized_args)
        Arguments.deserialize(serialized_args)
      end
  end
end
