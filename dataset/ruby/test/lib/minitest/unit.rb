
require "optparse"
require "rbconfig"
require "leakchecker"


module MiniTest

  def self.const_missing name # :nodoc:
    case name
    when :MINI_DIR then
      msg = "MiniTest::MINI_DIR was removed. Don't violate other's internals."
      warn "WAR\NING: #{msg}"
      warn "WAR\NING: Used by #{caller.first}."
      #nodyna <const_set-1440> <CS TRIVIAL (static values)>
      const_set :MINI_DIR, "bad value"
    else
      super
    end
  end


  class Assertion < Exception; end


  class Skip < Assertion; end

  class << self

    attr_accessor :backtrace_filter
  end

  class BacktraceFilter # :nodoc:
    def filter bt
      return ["No backtrace"] unless bt

      new_bt = []

      unless $DEBUG then
        bt.each do |line|
          break if line =~ /lib\/minitest/
          new_bt << line
        end

        new_bt = bt.reject { |line| line =~ /lib\/minitest/ } if new_bt.empty?
        new_bt = bt.dup if new_bt.empty?
      else
        new_bt = bt.dup
      end

      new_bt
    end
  end

  self.backtrace_filter = BacktraceFilter.new

  def self.filter_backtrace bt # :nodoc:
    backtrace_filter.filter bt
  end


  module Assertions
    UNDEFINED = Object.new # :nodoc:

    def UNDEFINED.inspect # :nodoc:
      "UNDEFINED" # again with the rdoc bugs... :(
    end


    def self.diff
      @diff = if (RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ &&
                  system("diff.exe", __FILE__, __FILE__)) then
                "diff.exe -u"
              elsif Minitest::Unit::Guard.maglev? then # HACK
                "diff -u"
              elsif system("gdiff", __FILE__, __FILE__)
                "gdiff -u" # solaris and kin suck
              elsif system("diff", __FILE__, __FILE__)
                "diff -u"
              else
                nil
              end unless defined? @diff

      @diff
    end


    def self.diff= o
      @diff = o
    end


    def diff exp, act
      require "tempfile"

      expect = mu_pp_for_diff exp
      butwas = mu_pp_for_diff act
      result = nil

      need_to_diff =
        MiniTest::Assertions.diff &&
        (expect.include?("\n")    ||
         butwas.include?("\n")    ||
         expect.size > 30         ||
         butwas.size > 30         ||
         expect == butwas)

      return "Expected: #{mu_pp exp}\n  Actual: #{mu_pp act}" unless
        need_to_diff

      tempfile_a = nil
      tempfile_b = nil

      Tempfile.open("expect") do |a|
        tempfile_a = a
        a.puts expect
        a.flush

        Tempfile.open("butwas") do |b|
          tempfile_b = b
          b.puts butwas
          b.flush

          result = `#{MiniTest::Assertions.diff} #{a.path} #{b.path}`
          result.sub!(/^\-\-\- .+/, "--- expected")
          result.sub!(/^\+\+\+ .+/, "+++ actual")

          if result.empty? then
            klass = exp.class
            result = [
                      "No visible difference in the #{klass}#inspect output.\n",
                      "You should look at the implementation of #== on ",
                      "#{klass} or its members.\n",
                      expect,
                     ].join
          end
        end
      end

      result
    ensure
      tempfile_a.close! if tempfile_a
      tempfile_b.close! if tempfile_b
    end


    def mu_pp obj
      s = obj.inspect
      s = s.encode Encoding.default_external if defined? Encoding
      s
    end


    def mu_pp_for_diff obj
      mu_pp(obj).gsub(/\\n/, "\n").gsub(/:0x[a-fA-F0-9]{4,}/m, ':0xXXXXXX')
    end

    def _assertions= n # :nodoc:
      @_assertions = n
    end

    def _assertions # :nodoc:
      @_assertions ||= 0
    end


    def assert test, msg = nil
      msg ||= "Failed assertion, no message given."
      self._assertions += 1
      unless test then
        msg = msg.call if Proc === msg
        raise MiniTest::Assertion, msg
      end
      true
    end


    def assert_empty obj, msg = nil
      msg = message(msg) { "Expected #{mu_pp(obj)} to be empty" }
      assert_respond_to obj, :empty?
      assert obj.empty?, msg
    end


    def assert_equal exp, act, msg = nil
      msg = message(msg, "") { diff exp, act }
      assert exp == act, msg
    end


    def assert_in_delta exp, act, delta = 0.001, msg = nil
      n = (exp - act).abs
      msg = message(msg) {
        "Expected |#{exp} - #{act}| (#{n}) to be <= #{delta}"
      }
      assert delta >= n, msg
    end


    def assert_in_epsilon a, b, epsilon = 0.001, msg = nil
      assert_in_delta a, b, [a.abs, b.abs].min * epsilon, msg
    end


    def assert_includes collection, obj, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(collection)} to include #{mu_pp(obj)}"
      }
      assert_respond_to collection, :include?
      assert collection.include?(obj), msg
    end


    def assert_instance_of cls, obj, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(obj)} to be an instance of #{cls}, not #{obj.class}"
      }

      assert obj.instance_of?(cls), msg
    end


    def assert_kind_of cls, obj, msg = nil # TODO: merge with instance_of
      msg = message(msg) {
        "Expected #{mu_pp(obj)} to be a kind of #{cls}, not #{obj.class}" }

      assert obj.kind_of?(cls), msg
    end


    def assert_match matcher, obj, msg = nil
      msg = message(msg) { "Expected #{mu_pp matcher} to match #{mu_pp obj}" }
      assert_respond_to matcher, :"=~"
      matcher = Regexp.new Regexp.escape matcher if String === matcher
      assert matcher =~ obj, msg
    end


    def assert_nil obj, msg = nil
      msg = message(msg) { "Expected #{mu_pp(obj)} to be nil" }
      assert obj.nil?, msg
    end


    def assert_operator o1, op, o2 = UNDEFINED, msg = nil
      return assert_predicate o1, op, msg if UNDEFINED == o2
      msg = message(msg) { "Expected #{mu_pp(o1)} to be #{op} #{mu_pp(o2)}" }
      assert o1.__send__(op, o2), msg
    end


    def assert_output stdout = nil, stderr = nil
      out, err = capture_io do
        yield
      end

      err_msg = Regexp === stderr ? :assert_match : :assert_equal if stderr
      out_msg = Regexp === stdout ? :assert_match : :assert_equal if stdout

      #nodyna <send-1441> <SD TRIVIAL (public methods)>
      y = send err_msg, stderr, err, "In stderr" if err_msg
      #nodyna <send-1442> <SD TRIVIAL (public methods)>
      x = send out_msg, stdout, out, "In stdout" if out_msg

      (!stdout || x) && (!stderr || y)
    end


    def assert_predicate o1, op, msg = nil
      msg = message(msg) { "Expected #{mu_pp(o1)} to be #{op}" }
      assert o1.__send__(op), msg
    end


    def assert_raises *exp
      msg = "#{exp.pop}.\n" if String === exp.last

      begin
        yield
      rescue MiniTest::Skip => e
        return e if exp.include? MiniTest::Skip
        raise e
      rescue Exception => e
        expected = exp.any? { |ex|
          if ex.instance_of? Module then
            e.kind_of? ex
          else
            e.instance_of? ex
          end
        }

        assert expected, proc {
          exception_details(e, "#{msg}#{mu_pp(exp)} exception expected, not")
        }

        return e
      end

      exp = exp.first if exp.size == 1

      flunk "#{msg}#{mu_pp(exp)} expected but nothing was raised."
    end


    def assert_respond_to obj, meth, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(obj)} (#{obj.class}) to respond to ##{meth}"
      }
      assert obj.respond_to?(meth), msg
    end


    def assert_same exp, act, msg = nil
      msg = message(msg) {
        data = [mu_pp(act), act.object_id, mu_pp(exp), exp.object_id]
        "Expected %s (oid=%d) to be the same as %s (oid=%d)" % data
      }
      assert exp.equal?(act), msg
    end


    def assert_send send_ary, m = nil
      recv, msg, *args = send_ary
      m = message(m) {
        "Expected #{mu_pp(recv)}.#{msg}(*#{mu_pp(args)}) to return true" }
      assert recv.__send__(msg, *args), m
    end


    def assert_silent
      assert_output "", "" do
        yield
      end
    end


    def assert_throws sym, msg = nil
      default = "Expected #{mu_pp(sym)} to have been thrown"
      caught = true
      catch(sym) do
        begin
          yield
        rescue ThreadError => e       # wtf?!? 1.8 + threads == suck
          default += ", not \:#{e.message[/uncaught throw \`(\w+?)\'/, 1]}"
        rescue ArgumentError => e     # 1.9 exception
          default += ", not #{e.message.split(/ /).last}"
        rescue NameError => e         # 1.8 exception
          default += ", not #{e.name.inspect}"
        end
        caught = false
      end

      assert caught, message(msg) { default }
    end


    def capture_io
      require 'stringio'

      captured_stdout, captured_stderr = StringIO.new, StringIO.new

      synchronize do
        orig_stdout, orig_stderr = $stdout, $stderr
        $stdout, $stderr         = captured_stdout, captured_stderr

        begin
          yield
        ensure
          $stdout = orig_stdout
          $stderr = orig_stderr
        end
      end

      return captured_stdout.string, captured_stderr.string
    end


    def capture_subprocess_io
      require 'tempfile'

      captured_stdout, captured_stderr = Tempfile.new("out"), Tempfile.new("err")

      synchronize do
        orig_stdout, orig_stderr = $stdout.dup, $stderr.dup
        $stdout.reopen captured_stdout
        $stderr.reopen captured_stderr

        begin
          yield

          $stdout.rewind
          $stderr.rewind

          [captured_stdout.read, captured_stderr.read]
        ensure
          $stdout.reopen orig_stdout
          $stderr.reopen orig_stderr
          orig_stdout.close
          orig_stderr.close
          captured_stdout.close!
          captured_stderr.close!
        end
      end
    end


    def exception_details e, msg
      [
       "#{msg}",
       "Class: <#{e.class}>",
       "Message: <#{e.message.inspect}>",
       "---Backtrace---",
       "#{MiniTest::filter_backtrace(e.backtrace).join("\n")}",
       "---------------",
      ].join "\n"
    end


    def flunk msg = nil
      msg ||= "Epic Fail!"
      assert false, msg
    end


    def message msg = nil, ending = ".", &default
      proc {
        msg = msg.call.chomp(".") if Proc === msg
        custom_message = "#{msg}.\n" unless msg.nil? or msg.to_s.empty?
        "#{custom_message}#{default.call}#{ending}"
      }
    end


    def pass msg = nil
      assert true
    end


    def refute test, msg = nil
      msg ||= "Failed refutation, no message given"
      not assert(! test, msg)
    end


    def refute_empty obj, msg = nil
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be empty" }
      assert_respond_to obj, :empty?
      refute obj.empty?, msg
    end


    def refute_equal exp, act, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(act)} to not be equal to #{mu_pp(exp)}"
      }
      refute exp == act, msg
    end


    def refute_in_delta exp, act, delta = 0.001, msg = nil
      n = (exp - act).abs
      msg = message(msg) {
        "Expected |#{exp} - #{act}| (#{n}) to not be <= #{delta}"
      }
      refute delta >= n, msg
    end


    def refute_in_epsilon a, b, epsilon = 0.001, msg = nil
      refute_in_delta a, b, a * epsilon, msg
    end


    def refute_includes collection, obj, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(collection)} to not include #{mu_pp(obj)}"
      }
      assert_respond_to collection, :include?
      refute collection.include?(obj), msg
    end


    def refute_instance_of cls, obj, msg = nil
      msg = message(msg) {
        "Expected #{mu_pp(obj)} to not be an instance of #{cls}"
      }
      refute obj.instance_of?(cls), msg
    end


    def refute_kind_of cls, obj, msg = nil # TODO: merge with instance_of
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be a kind of #{cls}" }
      refute obj.kind_of?(cls), msg
    end


    def refute_match matcher, obj, msg = nil
      msg = message(msg) {"Expected #{mu_pp matcher} to not match #{mu_pp obj}"}
      assert_respond_to matcher, :"=~"
      matcher = Regexp.new Regexp.escape matcher if String === matcher
      refute matcher =~ obj, msg
    end


    def refute_nil obj, msg = nil
      msg = message(msg) { "Expected #{mu_pp(obj)} to not be nil" }
      refute obj.nil?, msg
    end


    def refute_operator o1, op, o2 = UNDEFINED, msg = nil
      return refute_predicate o1, op, msg if UNDEFINED == o2
      msg = message(msg) { "Expected #{mu_pp(o1)} to not be #{op} #{mu_pp(o2)}"}
      refute o1.__send__(op, o2), msg
    end


    def refute_predicate o1, op, msg = nil
      msg = message(msg) { "Expected #{mu_pp(o1)} to not be #{op}" }
      refute o1.__send__(op), msg
    end


    def refute_respond_to obj, meth, msg = nil
      msg = message(msg) { "Expected #{mu_pp(obj)} to not respond to #{meth}" }

      refute obj.respond_to?(meth), msg
    end


    def refute_same exp, act, msg = nil
      msg = message(msg) {
        data = [mu_pp(act), act.object_id, mu_pp(exp), exp.object_id]
        "Expected %s (oid=%d) to not be the same as %s (oid=%d)" % data
      }
      refute exp.equal?(act), msg
    end


    def skip msg = nil, bt = caller
      msg ||= "Skipped, no message given"
      @skip = true
      raise MiniTest::Skip, msg, bt
    end


    def skipped?
      defined?(@skip) and @skip
    end


    def synchronize
      Minitest::Unit.runner.synchronize do
        yield
      end
    end
  end

  class Unit # :nodoc:
    VERSION = "4.7.5" # :nodoc:

    attr_accessor :report, :failures, :errors, :skips # :nodoc:
    attr_accessor :assertion_count                    # :nodoc:
    attr_writer   :test_count                         # :nodoc:
    attr_accessor :start_time                         # :nodoc:
    attr_accessor :help                               # :nodoc:
    attr_accessor :verbose                            # :nodoc:
    attr_writer   :options                            # :nodoc:


    attr_accessor :info_signal


    def options
      @options ||= {}
    end

    @@installed_at_exit ||= false
    @@out = $stdout
    @@after_tests = []


    def self.after_tests &block
      @@after_tests << block
    end


    def self.autorun
      at_exit {
        next if $! and not $!.kind_of? SystemExit

        exit_code = nil

        at_exit {
          @@after_tests.reverse_each(&:call)
          exit false if exit_code && exit_code != 0
        }

        exit_code = MiniTest::Unit.new.run ARGV
      } unless @@installed_at_exit
      @@installed_at_exit = true
    end


    def self.output
      @@out
    end


    def self.output= stream
      @@out = stream
    end


    def self.runner= runner
      @@runner = runner
    end


    def self.runner
      @@runner ||= self.new
    end


    def self.plugins
      @@plugins ||= (["run_tests"] +
                     public_instance_methods(false).
                     grep(/^run_/).map { |s| s.to_s }).uniq
    end


    def output
      self.class.output
    end

    def puts *a  # :nodoc:
      output.puts(*a)
    end

    def print *a # :nodoc:
      output.print(*a)
    end

    def test_count # :nodoc:
      @test_count ||= 0
    end


    def _run_anything type
      #nodyna <send-1443> <not yet classified>
      suites = TestCase.send "#{type}_suites"
      return if suites.empty?

      start = Time.now

      puts
      puts "# Running #{type}s:"
      puts

      @test_count, @assertion_count = 0, 0
      sync = output.respond_to? :"sync=" # stupid emacs
      old_sync, output.sync = output.sync, true if sync

      results = _run_suites suites, type

      @test_count      = results.inject(0) { |sum, (tc, _)| sum + tc }
      @assertion_count = results.inject(0) { |sum, (_, ac)| sum + ac }

      output.sync = old_sync if sync

      t = Time.now - start

      puts
      puts
      puts "Finished #{type}s in %.6fs, %.4f tests/s, %.4f assertions/s." %
        [t, test_count / t, assertion_count / t]

      report.each_with_index do |msg, i|
        puts "\n%3d) %s" % [i + 1, msg]
      end

      puts

      status
    end


    def _run_suites suites, type
      suites.map { |suite| _run_suite suite, type }
    end


    def _run_suite suite, type
      header = "#{type}_suite_header"
      #nodyna <send-1444> <not yet classified>
      puts send(header, suite) if respond_to? header

      filter = options[:filter] || '/./'
      filter = Regexp.new $1 if filter =~ /\/(.*)\//

      #nodyna <send-1445> <not yet classified>
      all_test_methods = suite.send "#{type}_methods"

      filtered_test_methods = all_test_methods.find_all { |m|
        filter === m || filter === "#{suite}##{m}"
      }

      leakchecker = LeakChecker.new

      assertions = filtered_test_methods.map { |method|
        inst = suite.new method
        inst._assertions = 0

        print "#{suite}##{method} = " if @verbose

        start_time = Time.now if @verbose
        result = inst.run self

        print "%.2f s = " % (Time.now - start_time) if @verbose
        print result
        puts if @verbose
        $stdout.flush

        leakchecker.check("#{inst.class}\##{inst.__name__}")

        inst._assertions
      }

      return assertions.size, assertions.inject(0) { |sum, n| sum + n }
    end


    def record suite, method, assertions, time, error
    end

    def location e # :nodoc:
      last_before_assertion = ""
      e.backtrace.reverse_each do |s|
        break if s =~ /in .(assert|refute|flunk|pass|fail|raise|must|wont)/
        last_before_assertion = s
      end
      last_before_assertion.sub(/:in .*$/, '')
    end


    def puke klass, meth, e
      e = case e
          when MiniTest::Skip then
            @skips += 1
            return "S" unless @verbose
            "Skipped:\n#{klass}##{meth} [#{location e}]:\n#{e.message}\n"
          when MiniTest::Assertion then
            @failures += 1
            "Failure:\n#{klass}##{meth} [#{location e}]:\n#{e.message}\n"
          else
            @errors += 1
            bt = MiniTest::filter_backtrace(e.backtrace).join "\n    "
            "Error:\n#{klass}##{meth}:\n#{e.class}: #{e.message}\n    #{bt}\n"
          end
      @report << e
      e[0, 1]
    end

    def initialize # :nodoc:
      @report = []
      @errors = @failures = @skips = 0
      @verbose = false
      @mutex = defined?(Mutex) ? Mutex.new : nil
      @info_signal = Signal.list['INFO']
    end

    def synchronize # :nodoc:
      if @mutex then
        @mutex.synchronize { yield }
      else
        yield
      end
    end

    def process_args args = [] # :nodoc:
      options = {}
      orig_args = args.dup

      OptionParser.new do |opts|
        opts.banner  = 'minitest options:'
        opts.version = MiniTest::Unit::VERSION

        opts.on '-h', '--help', 'Display this help.' do
          puts opts
          exit
        end

        opts.on '-s', '--seed SEED', Integer, "Sets random seed" do |m|
          options[:seed] = m.to_i
        end

        opts.on '-v', '--verbose', "Verbose. Show progress processing files." do
          options[:verbose] = true
        end

        opts.on '-n', '--name PATTERN', "Filter test names on pattern (e.g. /foo/)" do |a|
          options[:filter] = a
        end

        opts.parse! args
        orig_args -= args
      end

      unless options[:seed] then
        srand
        options[:seed] = srand % 0xFFFF
        orig_args << "--seed" << options[:seed].to_s
      end

      srand options[:seed]

      self.verbose = options[:verbose]
      @help = orig_args.map { |s| s =~ /[\s|&<>$()]/ ? s.inspect : s }.join " "

      options
    end


    def run args = []
      self.class.runner._run(args)
    end


    def _run args = []
      args = process_args args # ARGH!! blame test/unit process_args
      self.options.merge! args

      puts "Run options: #{help}"

      self.class.plugins.each do |plugin|
        #nodyna <send-1446> <not yet classified>
        send plugin
        break unless report.empty?
      end

      return failures + errors if self.test_count > 0 # or return nil...
    rescue Interrupt
      abort 'Interrupted'
    end


    def run_tests
      _run_anything :test
    end


    def status io = self.output
      format = "%d tests, %d assertions, %d failures, %d errors, %d skips"
      io.puts format % [test_count, assertion_count, failures, errors, skips]
    end


    module Guard


      def jruby? platform = RUBY_PLATFORM
        "java" == platform
      end


      def maglev? platform = defined?(RUBY_ENGINE) && RUBY_ENGINE
        "maglev" == platform
      end

      module_function :maglev?


      def mri? platform = RUBY_DESCRIPTION
        /^ruby/ =~ platform
      end


      def rubinius? platform = defined?(RUBY_ENGINE) && RUBY_ENGINE
        "rbx" == platform
      end


      def windows? platform = RUBY_PLATFORM
        /mswin|mingw/ =~ platform
      end
    end


    module LifecycleHooks

      def after_setup; end


      def before_setup; end


      def before_teardown; end


      def after_teardown; end
    end


    class TestCase
      include LifecycleHooks
      include Guard
      extend Guard

      attr_reader :__name__ # :nodoc:

      PASSTHROUGH_EXCEPTIONS = [NoMemoryError, SignalException,
                                Interrupt, SystemExit] # :nodoc:


      def run runner
        trap "INFO" do
          runner.report.each_with_index do |msg, i|
            warn "\n%3d) %s" % [i + 1, msg]
          end
          warn ''
          time = runner.start_time ? Time.now - runner.start_time : 0
          warn "Current Test: %s#%s %.2fs" % [self.class, self.__name__, time]
          runner.status $stderr
        end if runner.info_signal

        start_time = Time.now

        result = ""
        begin
          @passed = nil
          self.before_setup
          self.setup
          self.after_setup
          self.run_test self.__name__
          result = "." unless io?
          time = Time.now - start_time
          runner.record self.class, self.__name__, self._assertions, time, nil
          @passed = true
        rescue *PASSTHROUGH_EXCEPTIONS
          raise
        rescue Exception => e
          @passed = Skip === e
          time = Time.now - start_time
          runner.record self.class, self.__name__, self._assertions, time, e
          result = runner.puke self.class, self.__name__, e
        ensure
          %w{ before_teardown teardown after_teardown }.each do |hook|
            begin
              #nodyna <send-1447> <not yet classified>
              self.send hook
            rescue *PASSTHROUGH_EXCEPTIONS
              raise
            rescue Exception => e
              @passed = false
              runner.record self.class, self.__name__, self._assertions, time, e
              result = runner.puke self.class, self.__name__, e
            end
          end
          trap 'INFO', 'DEFAULT' if runner.info_signal
        end
        result
      end

      alias :run_test :__send__

      def initialize name # :nodoc:
        @__name__ = name
        @__io__ = nil
        @passed = nil
        @@current = self # FIX: make thread local
      end

      def self.current # :nodoc:
        @@current # FIX: make thread local
      end


      def io
        @__io__ = true
        MiniTest::Unit.output
      end


      def io?
        @__io__
      end

      def self.reset # :nodoc:
        @@test_suites = {}
      end

      reset


      def self.i_suck_and_my_tests_are_order_dependent!
        class << self
          undef_method :test_order if method_defined? :test_order
          #nodyna <define_method-1448> <not yet classified>
          define_method :test_order do :alpha end
        end
      end


      def self.make_my_diffs_pretty!
        require 'pp'

        #nodyna <define_method-1449> <not yet classified>
        define_method :mu_pp do |o|
          o.pretty_inspect
        end
      end

      def self.inherited klass # :nodoc:
        @@test_suites[klass] = true
        super
      end

      def self.test_order # :nodoc:
        :random
      end

      def self.test_suites # :nodoc:
        @@test_suites.keys.sort_by { |ts| ts.name.to_s }
      end

      def self.test_methods # :nodoc:
        methods = public_instance_methods(true).grep(/^test/).map { |m| m.to_s }

        case self.test_order
        when :parallel
          max = methods.size
          ParallelEach.new methods.sort.sort_by { rand max }
        when :random then
          max = methods.size
          methods.sort.sort_by { rand max }
        when :alpha, :sorted then
          methods.sort
        else
          raise "Unknown test_order: #{self.test_order.inspect}"
        end
      end


      def passed?
        @passed
      end


      def setup; end


      def teardown; end

      include MiniTest::Assertions
    end # class TestCase
  end # class Unit

  Test = Unit::TestCase
end # module MiniTest

Minitest = MiniTest # :nodoc: because ugh... I typo this all the time
