require 'rbconfig'
require 'tempfile'
require 'active_support/deprecation'

module Kernel
  def silence_warnings
    with_warnings(nil) { yield }
  end

  def enable_warnings
    with_warnings(true) { yield }
  end

  def with_warnings(flag)
    old_verbose, $VERBOSE = $VERBOSE, flag
    yield
  ensure
    $VERBOSE = old_verbose
  end

  def silence_stderr #:nodoc:
    ActiveSupport::Deprecation.warn(
      "`#silence_stderr` is deprecated and will be removed in the next release."
    ) #not thread-safe
    silence_stream(STDERR) { yield }
  end

  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end

  def suppress(*exception_classes)
    yield
  rescue *exception_classes
  end

  def capture(stream)
    ActiveSupport::Deprecation.warn(
      "`#capture(stream)` is deprecated and will be removed in the next release."
    ) #not thread-safe
    stream = stream.to_s
    captured_stream = Tempfile.new(stream)
    #nodyna <eval-1101> <EV COMPLEX (change-prone variables)>
    stream_io = eval("$#{stream}")
    origin_stream = stream_io.dup
    stream_io.reopen(captured_stream)

    yield

    stream_io.rewind
    return captured_stream.read
  ensure
    captured_stream.close
    captured_stream.unlink
    stream_io.reopen(origin_stream)
  end
  alias :silence :capture

  def quietly
    ActiveSupport::Deprecation.warn(
      "`#quietly` is deprecated and will be removed in the next release."
    ) #not thread-safe
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end
end
