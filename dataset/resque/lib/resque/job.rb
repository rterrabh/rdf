module Resque
  class Job
    def redis
      Resque.redis
    end

    def self.redis
      Resque.redis
    end

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
        raise DecodeException, e.message, e.backtrace
      end
    end

    def self.encode(object)
      if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
        MultiJson.dump object
      else
        MultiJson.encode object
      end
    end

    def self.decode(object)
      return unless object

      begin
        if MultiJson.respond_to?(:dump) && MultiJson.respond_to?(:load)
          MultiJson.load object
        else
          MultiJson.decode object
        end
      rescue ::MultiJson::DecodeError => e
        raise DecodeException, e.message, e.backtrace
      end
    end
    
    def classify(dashed_word)
      dashed_word.split('-').each { |part| part[0] = part[0].chr.upcase }.join
    end
    
    def constantize(camel_cased_word)
      camel_cased_word = camel_cased_word.to_s

      if camel_cased_word.include?('-')
        camel_cased_word = classify(camel_cased_word)
      end

      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        args = Module.method(:const_get).arity != 1 ? [false] : []

        if constant.const_defined?(name, *args)
          #nodyna <const_get-2956> <CG COMPLEX (change-prone variable)>
          constant = constant.const_get(name)
        else
          constant = constant.const_missing(name)
        end
      end
      constant
    end

    DontPerform = Class.new(StandardError)

    attr_accessor :worker

    attr_reader :queue

    attr_reader :payload

    def initialize(queue, payload)
      @queue = queue
      @payload = payload
      @failure_hooks_ran = false
    end

    def self.create(queue, klass, *args)
      Resque.validate(klass, queue)

      if Resque.inline?
        new(:inline, {'class' => klass, 'args' => decode(encode(args))}).perform
      else
        Resque.push(queue, :class => klass.to_s, :args => args)
      end
    end

    def self.destroy(queue, klass, *args)
      klass = klass.to_s
      queue = "queue:#{queue}"
      destroyed = 0

      if args.empty?
        redis.lrange(queue, 0, -1).each do |string|
          if decode(string)['class'] == klass
            destroyed += redis.lrem(queue, 0, string).to_i
          end
        end
      else
        destroyed += redis.lrem(queue, 0, encode(:class => klass, :args => args))
      end

      destroyed
    end

    def self.reserve(queue)
      return unless payload = Resque.pop(queue)
      new(queue, payload)
    end

    def perform
      job = payload_class
      job_args = args || []
      job_was_performed = false

      begin
        begin
          before_hooks.each do |hook|
            #nodyna <send-2957> <SD COMPLEX (array)>
            job.send(hook, *job_args)
          end
        rescue DontPerform
          return false
        end

        if around_hooks.empty?
          job.perform(*job_args)
          job_was_performed = true
        else
          stack = around_hooks.reverse.inject(nil) do |last_hook, hook|
            if last_hook
              lambda do
                #nodyna <send-2958> <SD COMPLEX (array)>
                job.send(hook, *job_args) { last_hook.call }
              end
            else
              lambda do
                #nodyna <send-2959> <SD COMPLEX (array)>
                job.send(hook, *job_args) do
                  result = job.perform(*job_args)
                  job_was_performed = true
                  result
                end
              end
            end
          end
          stack.call
        end

        after_hooks.each do |hook|
          #nodyna <send-2960> <SD COMPLEX (array)>
          job.send(hook, *job_args)
        end

        return job_was_performed

      rescue Object => e
        run_failure_hooks(e)
        raise e
      end
    end

    def payload_class
      @payload_class ||= constantize(@payload['class'])
    end

    def payload_class_name
      payload_class.to_s
    rescue NameError
      'No Name'
    end

    def has_payload_class?
      payload_class != Object
    rescue NameError
      false
    end

    def args
      @payload['args']
    end

    def fail(exception)
      run_failure_hooks(exception)
      Failure.create \
        :payload   => payload,
        :exception => exception,
        :worker    => worker,
        :queue     => queue
    end

    def recreate
      self.class.create(queue, payload_class, *args)
    end

    def inspect
      obj = @payload
      "(Job{%s} | %s | %s)" % [ @queue, obj['class'], obj['args'].inspect ]
    end

    def ==(other)
      queue == other.queue &&
        payload_class == other.payload_class &&
        args == other.args
    end

    def before_hooks
      @before_hooks ||= Plugin.before_hooks(payload_class)
    end

    def around_hooks
      @around_hooks ||= Plugin.around_hooks(payload_class)
    end

    def after_hooks
      @after_hooks ||= Plugin.after_hooks(payload_class)
    end

    def failure_hooks
      @failure_hooks ||= Plugin.failure_hooks(payload_class)
    end

    def run_failure_hooks(exception)
      begin
        job_args = args || []
        if has_payload_class?
          #nodyna <send-2961> <SD COMPLEX (array)>
          failure_hooks.each { |hook| payload_class.send(hook, exception, *job_args) } unless @failure_hooks_ran
        end
      ensure
        @failure_hooks_ran = true
      end
    end
  end
end
