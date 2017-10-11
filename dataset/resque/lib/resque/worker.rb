require 'time'
require 'set'

module Resque
  class Worker
    include Resque::Logging

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

    attr_accessor :cant_fork

    attr_accessor :term_timeout

    attr_accessor :term_child

    attr_accessor :run_at_exit_hooks

    attr_writer :to_s

    def self.all
      Array(redis.smembers(:workers)).map { |id| find(id) }.compact
    end

    def self.working
      names = all
      return [] unless names.any?

      names.map! { |name| "worker:#{name}" }

      reportedly_working = {}

      begin
        reportedly_working = redis.mapped_mget(*names).reject do |key, value|
          value.nil? || value.empty?
        end
      rescue Redis::Distributed::CannotDistribute
        names.each do |name|
          value = redis.get name
          reportedly_working[name] = value unless value.nil? || value.empty?
        end
      end

      reportedly_working.keys.map do |key|
        find key.sub("worker:", '')
      end.compact
    end

    def self.find(worker_id)
      if exists? worker_id
        queues = worker_id.split(':')[-1].split(',')
        worker = new(*queues)
        worker.to_s = worker_id
        worker
      else
        nil
      end
    end

    def self.attach(worker_id)
      find(worker_id)
    end

    def self.exists?(worker_id)
      redis.sismember(:workers, worker_id)
    end

    def initialize(*queues)
      @queues = queues.map { |queue| queue.to_s.strip }
      @shutdown = nil
      @paused = nil
      validate_queues
    end

    def validate_queues
      if @queues.nil? || @queues.empty?
        raise NoQueueError.new("Please give each worker at least one queue.")
      end
    end

    def work(interval = 5.0, &block)
      interval = Float(interval)
      $0 = "resque: Starting"
      startup

      loop do
        break if shutdown?

        if not paused? and job = reserve
          log "got: #{job.inspect}"
          job.worker = self
          working_on job

          procline "Processing #{job.queue} since #{Time.now.to_i} [#{job.payload_class_name}]"
          if @child = fork(job)
            srand # Reseeding
            procline "Forked #{@child} at #{Time.now.to_i}"
            begin
              Process.waitpid(@child)
            rescue SystemCallError
              nil
            end
            job.fail(DirtyExit.new($?.to_s)) if $?.signaled?
          else
            unregister_signal_handlers if will_fork? && term_child
            begin

              reconnect
              perform(job, &block)

            rescue Exception => exception
              report_failed_job(job,exception)
            end

            if will_fork?
              run_at_exit_hooks ? exit : exit!
            end
          end

          done_working
          @child = nil
        else
          break if interval.zero?
          log! "Sleeping for #{interval} seconds"
          procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
          sleep interval
        end
      end

      unregister_worker
    rescue Exception => exception
      unless exception.class == SystemExit && !@child && run_at_exit_hooks
        log "Failed to start worker : #{exception.inspect}"

        unregister_worker(exception)
      end
    end

    def process(job = nil, &block)
      return unless job ||= reserve

      job.worker = self
      working_on job
      perform(job, &block)
    ensure
      done_working
    end

    def report_failed_job(job,exception)
      log "#{job.inspect} failed: #{exception.inspect}"
      begin
        job.fail(exception)
      rescue Object => exception
        log "Received exception when reporting failure: #{exception.inspect}"
      end
      begin
        failed!
      rescue Object => exception
        log "Received exception when increasing failed jobs counter (redis issue) : #{exception.inspect}"
      end
    end

    def perform(job)
      begin
        run_hook :after_fork, job if will_fork?
        job.perform
      rescue Object => e
        report_failed_job(job,e)
      else
        log "done: #{job.inspect}"
      ensure
        yield job if block_given?
      end
    end

    def reserve
      queues.each do |queue|
        log! "Checking #{queue}"
        if job = Resque.reserve(queue)
          log! "Found job on #{queue}"
          return job
        end
      end

      nil
    rescue Exception => e
      log "Error reserving job: #{e.inspect}"
      log e.backtrace.join("\n")
      raise e
    end

    def reconnect
      tries = 0
      begin
        redis.client.reconnect
      rescue Redis::BaseConnectionError
        if (tries += 1) <= 3
          log "Error reconnecting to Redis; retrying"
          sleep(tries)
          retry
        else
          log "Error reconnecting to Redis; quitting"
          raise
        end
      end
    end

    def queues
      @queues.map do |queue|
        queue.strip!
        if (matched_queues = glob_match(queue)).empty?
          queue
        else
          matched_queues
        end
      end.flatten.uniq
    end

    def glob_match(pattern)
      Resque.queues.select do |queue|
        File.fnmatch?(pattern, queue)
      end.sort
    end

    def fork(job)
      return if @cant_fork

      run_hook :before_fork, job

      begin
        if Kernel.respond_to?(:fork)
          Kernel.fork if will_fork?
        else
          raise NotImplementedError
        end
      rescue NotImplementedError
        @cant_fork = true
        nil
      end
    end

    def startup
      Kernel.warn "WARNING: This way of doing signal handling is now deprecated. Please see http://hone.heroku.com/resque/2012/08/21/resque-signals.html for more info." unless term_child or $TESTING
      enable_gc_optimizations
      register_signal_handlers
      prune_dead_workers
      run_hook :before_first_fork
      register_worker

      $stdout.sync = true
    end

    def enable_gc_optimizations
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
    end

    def register_signal_handlers
      trap('TERM') { shutdown!  }
      trap('INT')  { shutdown!  }

      begin
        trap('QUIT') { shutdown   }
        if term_child
          trap('USR1') { new_kill_child }
        else
          trap('USR1') { kill_child }
        end
        trap('USR2') { pause_processing }
        trap('CONT') { unpause_processing }
      rescue ArgumentError
        warn "Signals QUIT, USR1, USR2, and/or CONT not supported."
      end

      log! "Registered signals"
    end

    def unregister_signal_handlers
      trap('TERM') do
        trap ('TERM') do 
        end  
        raise TermException.new("SIGTERM") 
      end 
      trap('INT', 'DEFAULT')

      begin
        trap('QUIT', 'DEFAULT')
        trap('USR1', 'DEFAULT')
        trap('USR2', 'DEFAULT')
      rescue ArgumentError
      end
    end

    def shutdown
      log 'Exiting...'
      @shutdown = true
    end

    def shutdown!
      shutdown
      if term_child
        new_kill_child
      else
        kill_child
      end
    end

    def shutdown?
      @shutdown
    end

    def kill_child
      if @child
        log! "Killing child at #{@child}"
        if `ps -o pid,state -p #{@child}`
          Process.kill("KILL", @child) rescue nil
        else
          log! "Child #{@child} not found, restarting."
          shutdown
        end
      end
    end

    def new_kill_child
      if @child
        unless Process.waitpid(@child, Process::WNOHANG)
          log! "Sending TERM signal to child #{@child}"
          Process.kill("TERM", @child)
          (term_timeout.to_f * 10).round.times do |i|
            sleep(0.1)
            return if Process.waitpid(@child, Process::WNOHANG)
          end
          log! "Sending KILL signal to child #{@child}"
          Process.kill("KILL", @child)
        else
          log! "Child #{@child} already quit."
        end
      end
    rescue SystemCallError
      log! "Child #{@child} already quit and reaped."
    end

    def paused?
      @paused
    end

    def pause_processing
      log "USR2 received; pausing job processing"
      @paused = true
    end

    def unpause_processing
      log "CONT received; resuming job processing"
      @paused = false
    end

    def prune_dead_workers
      all_workers = Worker.all
      known_workers = worker_pids unless all_workers.empty?
      all_workers.each do |worker|
        host, pid, worker_queues_raw = worker.id.split(':')
        worker_queues = worker_queues_raw.split(",")
        unless @queues.include?("*") || (worker_queues.to_set == @queues.to_set)
          next
        end
        next unless host == hostname
        next if known_workers.include?(pid)
        log! "Pruning dead worker: #{worker}"
        worker.unregister_worker
      end
    end

    def register_worker
      redis.pipelined do
        redis.sadd(:workers, self)
        started!
      end
    end

    def run_hook(name, *args)
      #nodyna <send-2964> <SD MODERATE (change-prone variables)>
      return unless hooks = Resque.send(name)
      msg = "Running #{name} hooks"
      msg << " with #{args.inspect}" if args.any?
      log msg

      hooks.each do |hook|
        args.any? ? hook.call(*args) : hook.call
      end
    end

    def unregister_worker(exception = nil)
      if (hash = processing) && !hash.empty?
        job = Job.new(hash['queue'], hash['payload'])
        job.worker = self
        job.fail(exception || DirtyExit.new)
      end

      redis.pipelined do
        redis.srem(:workers, self)
        redis.del("worker:#{self}")
        redis.del("worker:#{self}:started")

        Stat.clear("processed:#{self}")
        Stat.clear("failed:#{self}")
      end
    end

    def working_on(job)
      data = encode \
        :queue   => job.queue,
        :run_at  => Time.now.utc.iso8601,
        :payload => job.payload
      redis.set("worker:#{self}", data)
    end

    def done_working
      redis.pipelined do
        processed!
        redis.del("worker:#{self}")
      end
    end

    def processed
      Stat["processed:#{self}"]
    end

    def processed!
      Stat << "processed"
      Stat << "processed:#{self}"
    end

    def failed
      Stat["failed:#{self}"]
    end

    def failed!
      Stat << "failed"
      Stat << "failed:#{self}"
    end

    def started
      redis.get "worker:#{self}:started"
    end

    def started!
      redis.set("worker:#{self}:started", Time.now.to_s)
    end

    def job
      decode(redis.get("worker:#{self}")) || {}
    end
    alias_method :processing, :job

    def working?
      state == :working
    end

    def idle?
      state == :idle
    end

    def will_fork?
      !@cant_fork && !$TESTING && (ENV["FORK_PER_JOB"] != 'false')
    end

    def state
      redis.exists("worker:#{self}") ? :working : :idle
    end

    def ==(other)
      to_s == other.to_s
    end

    def inspect
      "#<Worker #{to_s}>"
    end

    def to_s
      @to_s ||= "#{hostname}:#{pid}:#{@queues.join(',')}"
    end
    alias_method :id, :to_s

    def hostname
      @hostname ||= `hostname`.chomp
    end

    def pid
      @pid ||= Process.pid
    end

    def worker_pids
      if RUBY_PLATFORM =~ /solaris/
        solaris_worker_pids
      elsif RUBY_PLATFORM =~ /mingw32/
        windows_worker_pids
      else
        linux_worker_pids
      end
    end

    def windows_worker_pids
      tasklist_output = `tasklist /FI "IMAGENAME eq ruby.exe" /FO list`.encode("UTF-8", Encoding.locale_charmap)
      tasklist_output.split($/).select { |line| line =~ /^PID:/}.collect{ |line| line.gsub /PID:\s+/, '' }
    end

    def linux_worker_pids
      `ps -A -o pid,command | grep "[r]esque" | grep -v "resque-web"`.split("\n").map do |line|
        line.split(' ')[0]
      end
    end

    def solaris_worker_pids
      `ps -A -o pid,comm | grep "[r]uby" | grep -v "resque-web"`.split("\n").map do |line|
        real_pid = line.split(' ')[0]
        pargs_command = `pargs -a #{real_pid} 2>/dev/null | grep [r]esque | grep -v "resque-web"`
        if pargs_command.split(':')[1] == " resque-#{Resque::Version}"
          real_pid
        end
      end.compact
    end

    def procline(string)
      $0 = "resque-#{Resque::Version}: #{string}"
      log! $0
    end

    def log(message)
      info(message)
    end

    def log!(message)
      debug(message)
    end

    def verbose
      logger_severity_deprecation_warning
      @verbose
    end

    def very_verbose
      logger_severity_deprecation_warning
      @very_verbose
    end

    def verbose=(value);
      logger_severity_deprecation_warning

      if value && !very_verbose
        Resque.logger.formatter = VerboseFormatter.new
      elsif !value
        Resque.logger.formatter = QuietFormatter.new
      end

      @verbose = value
    end

    def very_verbose=(value)
      logger_severity_deprecation_warning
      if value
        Resque.logger.formatter = VeryVerboseFormatter.new
      elsif !value && verbose
        Resque.logger.formatter = VerboseFormatter.new
      else
        Resque.logger.formatter = QuietFormatter.new
      end

      @very_verbose = value
    end

    def logger_severity_deprecation_warning
      return if $TESTING
      return if $warned_logger_severity_deprecation
      Kernel.warn "*** DEPRECATION WARNING: Resque::Worker#verbose and #very_verbose are deprecated. Please set Resque.logger.level instead"
      Kernel.warn "Called from: #{caller[0..5].join("\n\t")}"
      $warned_logger_severity_deprecation = true
      nil
    end
  end
end
