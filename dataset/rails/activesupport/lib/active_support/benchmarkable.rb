require 'active_support/core_ext/benchmark'
require 'active_support/core_ext/hash/keys'

module ActiveSupport
  module Benchmarkable
    def benchmark(message = "Benchmarking", options = {})
      if logger
        options.assert_valid_keys(:level, :silence)
        options[:level] ||= :info

        result = nil
        ms = Benchmark.ms { result = options[:silence] ? silence { yield } : yield }
        #nodyna <send-1122> <SD COMPLEX (change-prone variables)>
        logger.send(options[:level], '%s (%.1fms)' % [ message, ms ])
        result
      else
        yield
      end
    end
  end
end
