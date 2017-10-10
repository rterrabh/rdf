module Rake

  class Promise               # :nodoc: all
    NOT_SET = Object.new.freeze # :nodoc:

    attr_accessor :recorder

    def initialize(args, &block)
      @mutex = Mutex.new
      @result = NOT_SET
      @error = NOT_SET
      @args = args
      @block = block
    end

    def value
      unless complete?
        stat :sleeping_on, :item_id => object_id
        @mutex.synchronize do
          stat :has_lock_on, :item_id => object_id
          chore
          stat :releasing_lock_on, :item_id => object_id
        end
      end
      error? ? raise(@error) : @result
    end

    def work
      stat :attempting_lock_on, :item_id => object_id
      if @mutex.try_lock
        stat :has_lock_on, :item_id => object_id
        chore
        stat :releasing_lock_on, :item_id => object_id
        @mutex.unlock
      else
        stat :bailed_on, :item_id => object_id
      end
    end

    private

    def chore
      if complete?
        stat :found_completed, :item_id => object_id
        return
      end
      stat :will_execute, :item_id => object_id
      begin
        @result = @block.call(*@args)
      rescue Exception => e
        @error = e
      end
      stat :did_execute, :item_id => object_id
      discard
    end

    def result?
      ! @result.equal?(NOT_SET)
    end

    def error?
      ! @error.equal?(NOT_SET)
    end

    def complete?
      result? || error?
    end

    def discard
      @args = nil
      @block = nil
    end

    def stat(*args)
      @recorder.call(*args) if @recorder
    end

  end

end
