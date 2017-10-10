require 'stringio'
require 'rubygems/user_interaction'


class Gem::MockGemUi < Gem::StreamUI

  class InputEOFError < RuntimeError

    def initialize question
      super "Out of input for MockGemUi on #{question.inspect}"
    end

  end

  class TermError < RuntimeError
    attr_reader :exit_code

    def initialize exit_code
      super
      @exit_code = exit_code
    end
  end
  class SystemExitException < RuntimeError; end

  module TTY

    attr_accessor :tty

    def tty?()
      @tty = true unless defined?(@tty)
      @tty
    end

    def noecho
      yield self
    end
  end

  def initialize(input = "")
    ins = StringIO.new input
    outs = StringIO.new
    errs = StringIO.new

    ins.extend TTY
    outs.extend TTY
    errs.extend TTY

    super ins, outs, errs, true

    @terminated = false
  end

  def ask question
    raise InputEOFError, question if @ins.eof?

    super
  end

  def input
    @ins.string
  end

  def output
    @outs.string
  end

  def error
    @errs.string
  end

  def terminated?
    @terminated
  end

  def terminate_interaction(status=0)
    @terminated = true

    raise TermError, status if status != 0
    raise SystemExitException
  end

end

