module ActiveSupport
  class Deprecation
    module Reporting
      attr_accessor :silenced
      attr_accessor :gem_name

      def warn(message = nil, callstack = nil)
        return if silenced

        callstack ||= caller(2)
        deprecation_message(callstack, message).tap do |m|
          behavior.each { |b| b.call(m, callstack) }
        end
      end

      def silence
        old_silenced, @silenced = @silenced, true
        yield
      ensure
        @silenced = old_silenced
      end

      def deprecation_warning(deprecated_method_name, message = nil, caller_backtrace = nil)
        caller_backtrace ||= caller(2)
        deprecated_method_warning(deprecated_method_name, message).tap do |msg|
          warn(msg, caller_backtrace)
        end
      end

      private
        def deprecated_method_warning(method_name, message = nil)
          warning = "#{method_name} is deprecated and will be removed from #{gem_name} #{deprecation_horizon}"
          case message
            when Symbol then "#{warning} (use #{message} instead)"
            when String then "#{warning} (#{message})"
            else warning
          end
        end

        def deprecation_message(callstack, message = nil)
          message ||= "You are using deprecated behavior which will be removed from the next major or minor release."
          message += '.' unless message =~ /\.$/
          "DEPRECATION WARNING: #{message} #{deprecation_caller_message(callstack)}"
        end

        def deprecation_caller_message(callstack)
          file, line, method = extract_callstack(callstack)
          if file
            if line && method
              "(called from #{method} at #{file}:#{line})"
            else
              "(called from #{file}:#{line})"
            end
          end
        end

        def extract_callstack(callstack)
          rails_gem_root = File.expand_path("../../../../..", __FILE__) + "/"
          offending_line = callstack.find { |line| !line.start_with?(rails_gem_root) } || callstack.first
          if offending_line
            if md = offending_line.match(/^(.+?):(\d+)(?::in `(.*?)')?/)
              md.captures
            else
              offending_line
            end
          end
        end
    end
  end
end
