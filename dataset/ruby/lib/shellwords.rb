
module Shellwords
  def shellsplit(line)
    words = []
    field = ''
    line.scan(/\G\s*(?>([^\s\\\'\"]+)|'([^\']*)'|"((?:[^\"\\]|\\.)*)"|(\\.?)|(\S))(\s|\z)?/m) do
      |word, sq, dq, esc, garbage, sep|
      raise ArgumentError, "Unmatched double quote: #{line.inspect}" if garbage
      field << (word || sq || (dq || esc).gsub(/\\(.)/, '\\1'))
      if sep
        words << field
        field = ''
      end
    end
    words
  end

  alias shellwords shellsplit

  module_function :shellsplit, :shellwords

  class << self
    alias split shellsplit
  end

  def shellescape(str)
    str = str.to_s

    return "''" if str.empty?

    str = str.dup

    str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1")

    str.gsub!(/\n/, "'\n'")

    return str
  end

  module_function :shellescape

  class << self
    alias escape shellescape
  end

  def shelljoin(array)
    array.map { |arg| shellescape(arg) }.join(' ')
  end

  module_function :shelljoin

  class << self
    alias join shelljoin
  end
end

class String
  def shellsplit
    Shellwords.split(self)
  end

  def shellescape
    Shellwords.escape(self)
  end
end

class Array
  def shelljoin
    Shellwords.join(self)
  end
end
