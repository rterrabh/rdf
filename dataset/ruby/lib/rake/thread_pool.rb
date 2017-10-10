require 'thread'
require 'set'

require 'rake/promise'

module Rake

  class ThreadPool # :nodoc: all

    def initialize(thread_count)
      @max_active_threads = [thread_count, 0].max
      @threads = Set.new
      @threads_mon = Monitor.new
      @queue = Queue.new
      @join_cond = @threads_mon.new_cond

      @history_start_time = nil
      @history = []
      @history_mon = Monitor.new
      @total_threads_in_play = 0
    end

    def future(*args, &block)
      promise = Promise.new(args, &block)
      promise.recorder = lambda { |*stats| stat(*stats) }

      @queue.enq promise
      stat :queued, :item_id => promise.object_id
      start_thread
      promise
    end

    def join
      @threads_mon.synchronize do
        begin
          stat :joining
          @join_cond.wait unless @threads.empty?
          stat :joined
        rescue Exception => e
          stat :joined
          $stderr.puts e
          $stderr.print "Queue contains #{@queue.size} items. " +
            "Thread pool contains #{@threads.count} threads\n"
          $stderr.print "Current Thread #{Thread.current} status = " +
            "#{Thread.current.status}\n"
          $stderr.puts e.backtrace.join("\n")
          @threads.each do |t|
            $stderr.print "Thread #{t} status = #{t.status}\n"
            $stderr.puts t.backtrace.join("\n") if t.respond_to? :backtrace
          end
          raise e
        end
      end
    end

    def gather_history          #:nodoc:
      @history_start_time = Time.now if @history_start_time.nil?
    end

    def history                 # :nodoc:
      @history_mon.synchronize { @history.dup }.
        sort_by { |i| i[:time] }.
        each { |i| i[:time] -= @history_start_time }
    end

    def statistics              #  :nodoc:
      {
        :total_threads_in_play => @total_threads_in_play,
        :max_active_threads => @max_active_threads,
      }
    end

    private

    def process_queue_item      #:nodoc:
      return false if @queue.empty?

      promise = @queue.deq(true)
      stat :dequeued, :item_id => promise.object_id
      promise.work
      return true

      rescue ThreadError # this means the queue is empty
      false
    end

    def safe_thread_count
      @threads_mon.synchronize do
        @threads.count
      end
    end

    def start_thread # :nodoc:
      @threads_mon.synchronize do
        next unless @threads.count < @max_active_threads

        t = Thread.new do
          begin
            while safe_thread_count <= @max_active_threads
              break unless process_queue_item
            end
          ensure
            @threads_mon.synchronize do
              @threads.delete Thread.current
              stat :ended, :thread_count => @threads.count
              @join_cond.broadcast if @threads.empty?
            end
          end
        end

        @threads << t
        stat(
          :spawned,
          :new_thread   => t.object_id,
          :thread_count => @threads.count)
        @total_threads_in_play = @threads.count if
          @threads.count > @total_threads_in_play
      end
    end

    def stat(event, data=nil) # :nodoc:
      return if @history_start_time.nil?
      info = {
        :event  => event,
        :data   => data,
        :time   => Time.now,
        :thread => Thread.current.object_id,
      }
      @history_mon.synchronize { @history << info }
    end


    def __queue__ # :nodoc:
      @queue
    end
  end

end
