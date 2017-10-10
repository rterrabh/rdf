module Resque
  module Failure
    def self.create(options = {})
      backend.new(*options.values_at(:exception, :worker, :queue, :payload)).save
    end

    def self.backend=(backend)
      @backend = backend
    end

    def self.backend
      return @backend if @backend

      case ENV['FAILURE_BACKEND']
      when 'redis_multi_queue'
        require 'resque/failure/redis_multi_queue'
        @backend = Failure::RedisMultiQueue
      when 'redis', nil
        require 'resque/failure/redis'
        @backend = Failure::Redis
      else
        raise ArgumentError, "invalid failure backend: #{FAILURE_BACKEND}"
      end
    end

    def self.failure_queue_name(job_queue_name)
      name = "#{job_queue_name}_failed"
      Resque.redis.sadd(:failed_queues, name)
      name
    end

    def self.job_queue_name(failure_queue_name)
      failure_queue_name.sub(/_failed$/, '')
    end

    def self.queues
      backend.queues
    end

    def self.count(queue = nil, class_name = nil)
      backend.count(queue, class_name)
    end

    def self.all(offset = 0, limit = 1, queue = nil)
      backend.all(offset, limit, queue)
    end

    def self.each(offset = 0, limit = self.count, queue = nil, class_name = nil, order = 'desc', &block)
      backend.each(offset, limit, queue, class_name, order, &block)
    end

    def self.url
      backend.url
    end

    def self.clear(queue = nil)
      backend.clear(queue)
    end

    def self.requeue(id)
      backend.requeue(id)
    end

    def self.remove(id)
      backend.remove(id)
    end
    
    def self.requeue_queue(queue)
      backend.requeue_queue(queue)
    end

    def self.remove_queue(queue)
      backend.remove_queue(queue)
    end
  end
end
