module ActiveSupport
  class BacktraceCleaner
    def initialize
      @filters, @silencers = [], []
    end

    def clean(backtrace, kind = :silent)
      filtered = filter_backtrace(backtrace)

      case kind
      when :silent
        silence(filtered)
      when :noise
        noise(filtered)
      else
        filtered
      end
    end
    alias :filter :clean

    def add_filter(&block)
      @filters << block
    end

    def add_silencer(&block)
      @silencers << block
    end

    def remove_silencers!
      @silencers = []
    end

    def remove_filters!
      @filters = []
    end

    private
      def filter_backtrace(backtrace)
        @filters.each do |f|
          backtrace = backtrace.map { |line| f.call(line) }
        end

        backtrace
      end

      def silence(backtrace)
        @silencers.each do |s|
          backtrace = backtrace.reject { |line| s.call(line) }
        end

        backtrace
      end

      def noise(backtrace)
        backtrace - silence(backtrace)
      end
  end
end
