
require "thread.rb"
require "e2mmap.rb"

class ThreadsWait
  extend Exception2MessageMapper
  def_exception("ErrNoWaitingThread", "No threads for waiting.")
  def_exception("ErrNoFinishedThread", "No finished threads.")

  def ThreadsWait.all_waits(*threads) # :yield: thread
    tw = ThreadsWait.new(*threads)
    if block_given?
      tw.all_waits do |th|
        yield th
      end
    else
      tw.all_waits
    end
  end

  def initialize(*threads)
    @threads = []
    @wait_queue = Queue.new
    join_nowait(*threads) unless threads.empty?
  end

  attr_reader :threads

  def empty?
    @threads.empty?
  end

  def finished?
    !@wait_queue.empty?
  end

  def join(*threads)
    join_nowait(*threads)
    next_wait
  end

  def join_nowait(*threads)
    threads.flatten!
    @threads.concat threads
    for th in threads
      Thread.start(th) do |t|
        begin
          t.join
        ensure
          @wait_queue.push t
        end
      end
    end
  end

  def next_wait(nonblock = nil)
    ThreadsWait.fail ErrNoWaitingThread if @threads.empty?
    begin
      @threads.delete(th = @wait_queue.pop(nonblock))
      th
    rescue ThreadError
      ThreadsWait.fail ErrNoFinishedThread
    end
  end

  def all_waits
    until @threads.empty?
      th = next_wait
      yield th if block_given?
    end
  end
end


ThWait = ThreadsWait

