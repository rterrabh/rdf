require 'minitest/unit'
require 'pp'

module Test
  module Unit
    module Assertions
      include MiniTest::Assertions

      def mu_pp(obj) #:nodoc:
        obj.pretty_inspect.chomp
      end

      MINI_DIR = File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), "minitest") #:nodoc:

      def assert(test, *msgs)
        case msg = msgs.first
        when String, Proc
        when nil
          msgs.shift
        else
          bt = caller.reject { |s| s.start_with?(MINI_DIR) }
          raise ArgumentError, "assertion message must be String or Proc, but #{msg.class} was given.", bt
        end unless msgs.empty?
        super
      end

      def assert_block(*msgs)
        assert yield, *msgs
      end

      def assert_raise(*exp, &b)
        case exp.last
        when String, Proc
          msg = exp.pop
        end

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
            exception_details(e, message(msg) {"#{mu_pp(exp)} exception expected, not"}.call)
          }

          return e
        end

        exp = exp.first if exp.size == 1

        flunk(message(msg) {"#{mu_pp(exp)} expected but nothing was raised"})
      end

      def assert_raise_with_message(exception, expected, msg = nil, &block)
        case expected
        when String
          assert = :assert_equal
        when Regexp
          assert = :assert_match
        else
          raise TypeError, "Expected #{expected.inspect} to be a kind of String or Regexp, not #{expected.class}"
        end

        ex = assert_raise(exception, msg || proc {"Exception(#{exception}) with message matches to #{expected.inspect}"}) {yield}
        msg = message(msg, "") {"Expected Exception(#{exception}) was raised, but the message doesn't match"}

        if assert == :assert_equal
          assert_equal(expected, ex.message, msg)
        else
          msg = message(msg) { "Expected #{mu_pp expected} to match #{mu_pp ex.message}" }
          assert expected =~ ex.message, msg
          #nodyna <eval-1431> <EV COMPLEX (change-prone variables)>
          block.binding.eval("proc{|_|$~=_}").call($~)
        end
        ex
      end

      def assert_nothing_raised(*args)
        self._assertions += 1
        if Module === args.last
          msg = nil
        else
          msg = args.pop
        end
        begin
          line = __LINE__; yield
        rescue MiniTest::Skip
          raise
        rescue Exception => e
          bt = e.backtrace
          as = e.instance_of?(MiniTest::Assertion)
          if as
            ans = /\A#{Regexp.quote(__FILE__)}:#{line}:in /o
            bt.reject! {|ln| ans =~ ln}
          end
          if ((args.empty? && !as) ||
              args.any? {|a| a.instance_of?(Module) ? e.is_a?(a) : e.class == a })
            msg = message(msg) { "Exception raised:\n<#{mu_pp(e)}>" }
            raise MiniTest::Assertion, msg.call, bt
          else
            raise
          end
        end
        nil
      end

      def assert_nothing_thrown(msg=nil)
        begin
          ret = yield
        rescue ArgumentError => error
          raise error if /\Auncaught throw (.+)\z/m !~ error.message
          msg = message(msg) { "<#{$1}> was thrown when nothing was expected" }
          flunk(msg)
        end
        assert(true, "Expected nothing to be thrown")
        ret
      end

      def assert_throw(tag, msg = nil)
        ret = catch(tag) do
          begin
            yield(tag)
          rescue UncaughtThrowError => e
            thrown = e.tag
          end
          msg = message(msg) {
            "Expected #{mu_pp(tag)} to have been thrown"\
            "#{%Q[, not #{thrown}] if thrown}"
          }
          assert(false, msg)
        end
        assert(true)
        ret
      end

      def assert_equal(exp, act, msg = nil)
        msg = message(msg) {
          exp_str = mu_pp(exp)
          act_str = mu_pp(act)
          exp_comment = ''
          act_comment = ''
          if exp_str == act_str
            if (exp.is_a?(String) && act.is_a?(String)) ||
               (exp.is_a?(Regexp) && act.is_a?(Regexp))
              exp_comment = " (#{exp.encoding})"
              act_comment = " (#{act.encoding})"
            elsif exp.is_a?(Float) && act.is_a?(Float)
              exp_str = "%\#.#{Float::DIG+2}g" % exp
              act_str = "%\#.#{Float::DIG+2}g" % act
            elsif exp.is_a?(Time) && act.is_a?(Time)
              if exp.subsec * 1000_000_000 == exp.nsec
                exp_comment = " (#{exp.nsec}[ns])"
              else
                exp_comment = " (subsec=#{exp.subsec})"
              end
              if act.subsec * 1000_000_000 == act.nsec
                act_comment = " (#{act.nsec}[ns])"
              else
                act_comment = " (subsec=#{act.subsec})"
              end
            elsif exp.class != act.class
              exp_comment = " (#{exp.class})"
              act_comment = " (#{act.class})"
            end
          elsif !Encoding.compatible?(exp_str, act_str)
            if exp.is_a?(String) && act.is_a?(String)
              exp_str = exp.dump
              act_str = act.dump
              exp_comment = " (#{exp.encoding})"
              act_comment = " (#{act.encoding})"
            else
              exp_str = exp_str.dump
              act_str = act_str.dump
            end
          end
          "<#{exp_str}>#{exp_comment} expected but was\n<#{act_str}>#{act_comment}"
        }
        assert(exp == act, msg)
      end

      def assert_not_nil(exp, msg=nil)
        msg = message(msg) { "<#{mu_pp(exp)}> expected to not be nil" }
        assert(!exp.nil?, msg)
      end

      def assert_not_equal(exp, act, msg=nil)
        msg = message(msg) { "<#{mu_pp(exp)}> expected to be != to\n<#{mu_pp(act)}>" }
        assert(exp != act, msg)
      end

      def assert_no_match(regexp, string, msg=nil)
        assert_instance_of(Regexp, regexp, "The first argument to assert_no_match should be a Regexp.")
        self._assertions -= 1
        msg = message(msg) { "<#{mu_pp(regexp)}> expected to not match\n<#{mu_pp(string)}>" }
        assert(regexp !~ string, msg)
      end

      def assert_not_same(expected, actual, message="")
        msg = message(msg) { build_message(message, <<EOT, expected, expected.__id__, actual, actual.__id__) }
<?>
with id <?> expected to not be equal\\? to
<?>
with id <?>.
EOT
        assert(!actual.equal?(expected), msg)
      end

      def assert_respond_to obj, (meth, priv), msg = nil
        if priv
          msg = message(msg) {
            "Expected #{mu_pp(obj)} (#{obj.class}) to respond to ##{meth}#{" privately" if priv}"
          }
          return assert obj.respond_to?(meth, priv), msg
        end
        super if !caller[0].rindex(MINI_DIR, 0) || !obj.respond_to?(meth)
      end

      def assert_send send_ary, m = nil
        recv, msg, *args = send_ary
        m = message(m) {
          if args.empty?
            argsstr = ""
          else
            (argsstr = mu_pp(args)).sub!(/\A\[(.*)\]\z/m, '(\1)')
          end
          "Expected #{mu_pp(recv)}.#{msg}#{argsstr} to return true"
        }
        assert recv.__send__(msg, *args), m
      end

      def assert_not_send send_ary, m = nil
        recv, msg, *args = send_ary
        m = message(m) {
          if args.empty?
            argsstr = ""
          else
            (argsstr = mu_pp(args)).sub!(/\A\[(.*)\]\z/m, '(\1)')
          end
          "Expected #{mu_pp(recv)}.#{msg}#{argsstr} to return false"
        }
        assert !recv.__send__(msg, *args), m
      end

      ms = instance_methods(true).map {|sym| sym.to_s }
      ms.grep(/\Arefute_/) do |m|
        mname = ('assert_not_' << m.to_s[/.*?_(.*)/, 1])
        alias_method(mname, m) unless ms.include? mname
      end
      alias assert_include assert_includes
      alias assert_not_include assert_not_includes

      def assert_all?(obj, m = nil, &blk)
        failed = []
        obj.each do |*a, &b|
          unless blk.call(*a, &b)
            failed << (a.size > 1 ? a : a[0])
          end
        end
        assert(failed.empty?, message(m) {failed.pretty_inspect})
      end

      def assert_not_all?(obj, m = nil, &blk)
        failed = []
        obj.each do |*a, &b|
          if blk.call(*a, &b)
            failed << a.size > 1 ? a : a[0]
          end
        end
        assert(failed.empty?, message(m) {failed.pretty_inspect})
      end

      def build_message(head, template=nil, *arguments) #:nodoc:
        template &&= template.chomp
        template.gsub(/\G((?:[^\\]|\\.)*?)(\\)?\?/) { $1 + ($2 ? "?" : mu_pp(arguments.shift)) }
      end

      def message(msg = nil, *args, &default) # :nodoc:
        if Proc === msg
          super(nil, *args) do
            ary = [msg.call, (default.call if default)].compact.reject(&:empty?)
            if 1 < ary.length
              ary[0...-1] = ary[0...-1].map {|str| str.sub(/(?<!\.)\z/, '.') }
            end
            ary.join("\n")
          end
        else
          super
        end
      end
    end
  end
end
