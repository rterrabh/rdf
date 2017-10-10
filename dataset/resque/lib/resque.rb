require 'mono_logger'
require 'redis/namespace'

require 'resque/version'

require 'resque/errors'

require 'resque/failure'
require 'resque/failure/base'

require 'resque/helpers'
require 'resque/stat'
require 'resque/logging'
require 'resque/log_formatters/quiet_formatter'
require 'resque/log_formatters/verbose_formatter'
require 'resque/log_formatters/very_verbose_formatter'
require 'resque/job'
require 'resque/worker'
require 'resque/plugin'

require 'resque/vendor/utf8_util'

module Resque
  extend self

  def encode(object)
    if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
      MultiJson.dump object
    else
      MultiJson.encode object
    end
  end

  def decode(object)
    return unless object

    begin
      if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
        MultiJson.load object
      else
        MultiJson.decode object
      end
    rescue ::MultiJson::DecodeError => e
      raise Helpers::DecodeException, e.message, e.backtrace
    end
  end

  extend Forwardable

  def self.config=(options = {})
    @config = Config.new(options)
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config
  end

  def redis=(server)
    case server
    when String
      if server =~ /redis\:\/\//
        redis = Redis.connect(:url => server, :thread_safe => true)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = Redis.new(:host => host, :port => port,
          :thread_safe => true, :db => db)
      end
      namespace ||= :resque

      @redis = Redis::Namespace.new(namespace, :redis => redis)
    when Redis::Namespace
      @redis = server
    else
      @redis = Redis::Namespace.new(:resque, :redis => server)
    end
  end

  def redis
    return @redis if @redis
    self.redis = Redis.respond_to?(:connect) ? Redis.connect : "localhost:6379"
    self.redis
  end

  def redis_id
    if redis.respond_to?(:server)
      redis.server
    elsif redis.respond_to?(:nodes) # distributed
      redis.nodes.map { |n| n.id }.join(', ')
    else
      redis.client.id
    end
  end

  attr_accessor :logger

  def before_first_fork(&block)
    block ? register_hook(:before_first_fork, block) : hooks(:before_first_fork)
  end

  def before_first_fork=(block)
    register_hook(:before_first_fork, block)
  end

  def before_fork(&block)
    block ? register_hook(:before_fork, block) : hooks(:before_fork)
  end

  def before_fork=(block)
    register_hook(:before_fork, block)
  end

  def after_fork(&block)
    block ? register_hook(:after_fork, block) : hooks(:after_fork)
  end

  def after_fork=(block)
    register_hook(:after_fork, block)
  end

  def before_pause(&block)
    block ? register_hook(:before_pause, block) : hooks(:before_pause)
  end

  attr_writer :before_pause

  def after_pause(&block)
    block ? register_hook(:after_pause, block) : hooks(:after_pause)
  end

  attr_writer :after_pause

  def to_s
    "Resque Client connected to #{redis_id}"
  end

  attr_accessor :inline

  alias :inline? :inline


  def push(queue, item)
    redis.pipelined do
      watch_queue(queue)
      redis.rpush "queue:#{queue}", encode(item)
    end
  end

  def pop(queue)
    decode redis.lpop("queue:#{queue}")
  end

  def size(queue)
    redis.llen("queue:#{queue}").to_i
  end

  def peek(queue, start = 0, count = 1)
    list_range("queue:#{queue}", start, count)
  end

  def list_range(key, start = 0, count = 1)
    if count == 1
      decode redis.lindex(key, start)
    else
      Array(redis.lrange(key, start, start+count-1)).map do |item|
        decode item
      end
    end
  end

  def queues
    Array(redis.smembers(:queues))
  end

  def remove_queue(queue)
    redis.pipelined do
      redis.srem(:queues, queue.to_s)
      redis.del("queue:#{queue}")
    end
  end

  def watch_queue(queue)
    redis.sadd(:queues, queue.to_s)
  end



  def enqueue(klass, *args)
    enqueue_to(queue_from_class(klass), klass, *args)
  end

  def enqueue_to(queue, klass, *args)
    before_hooks = Plugin.before_enqueue_hooks(klass).collect do |hook|
      #nodyna <send-2965> <not yet classified>
      klass.send(hook, *args)
    end
    return nil if before_hooks.any? { |result| result == false }

    Job.create(queue, klass, *args)

    Plugin.after_enqueue_hooks(klass).each do |hook|
      #nodyna <send-2966> <not yet classified>
      klass.send(hook, *args)
    end

    return true
  end

  def dequeue(klass, *args)
    before_hooks = Plugin.before_dequeue_hooks(klass).collect do |hook|
      #nodyna <send-2967> <not yet classified>
      klass.send(hook, *args)
    end
    return if before_hooks.any? { |result| result == false }

    destroyed = Job.destroy(queue_from_class(klass), klass, *args)

    Plugin.after_dequeue_hooks(klass).each do |hook|
      #nodyna <send-2968> <not yet classified>
      klass.send(hook, *args)
    end
    
    destroyed
  end

  def queue_from_class(klass)
    #nodyna <instance_variable_get-2969> <not yet classified>
    klass.instance_variable_get(:@queue) ||
      (klass.respond_to?(:queue) and klass.queue)
  end

  def reserve(queue)
    Job.reserve(queue)
  end

  def validate(klass, queue = nil)
    queue ||= queue_from_class(klass)

    if !queue
      raise NoQueueError.new("Jobs must be placed onto a queue.")
    end

    if klass.to_s.empty?
      raise NoClassError.new("Jobs must be given a class.")
    end
  end



  def workers
    Worker.all
  end

  def working
    Worker.working
  end

  def remove_worker(worker_id)
    worker = Resque::Worker.find(worker_id)
    worker.unregister_worker
  end


  def info
    return {
      :pending   => queues.inject(0) { |m,k| m + size(k) },
      :processed => Stat[:processed],
      :queues    => queues.size,
      :workers   => workers.size.to_i,
      :working   => working.size,
      :failed    => Resque.redis.llen(:failed).to_i,
      :servers   => [redis_id],
      :environment  => ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
    }
  end

  def keys
    redis.keys("*").map do |key|
      key.sub("#{redis.namespace}:", '')
    end
  end

  private

  def register_hook(name, block)
    return clear_hooks(name) if block.nil?

    @hooks ||= {}
    @hooks[name] ||= []

    block = Array(block)
    @hooks[name].concat(block)
  end

  def clear_hooks(name)
    @hooks && @hooks[name] = []
  end

  def hooks(name)
    (@hooks && @hooks[name]) || []
  end
end

Resque.logger           = MonoLogger.new(STDOUT)
Resque.logger.formatter = Resque::QuietFormatter.new
