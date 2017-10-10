module Resque
  class NoQueueError < RuntimeError; end

  class NoClassError < RuntimeError; end

  class DirtyExit < RuntimeError; end

  class TermException < SignalException; end
end
