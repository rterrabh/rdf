module Kernel
  unless respond_to?(:debugger)
    def debugger
      message = "\n***** Debugger requested, but was not available (ensure the debugger gem is listed in Gemfile/installed as gem): Start server with --debugger to enable *****\n"
      defined?(Rails.logger) ? Rails.logger.info(message) : $stderr.puts(message)
    end
    alias breakpoint debugger unless respond_to?(:breakpoint)
  end
end
