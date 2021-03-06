
module Gem::Util

  @silent_mutex = nil


  def self.gunzip(data)
    require 'zlib'
    require 'rubygems/util/stringio'
    data = Gem::StringSource.new data

    unzipped = Zlib::GzipReader.new(data).read
    unzipped.force_encoding Encoding::BINARY if Object.const_defined? :Encoding
    unzipped
  end


  def self.gzip(data)
    require 'zlib'
    require 'rubygems/util/stringio'
    zipped = Gem::StringSink.new
    zipped.set_encoding Encoding::BINARY if Object.const_defined? :Encoding

    Zlib::GzipWriter.wrap zipped do |io| io.write data end

    zipped.string
  end


  def self.inflate(data)
    require 'zlib'
    Zlib::Inflate.inflate data
  end


  def self.popen *command
    IO.popen command, &:read
  rescue TypeError # ruby 1.8 only supports string command
    r, w = IO.pipe

    pid = fork do
      STDIN.close
      STDOUT.reopen w

      exec(*command)
    end

    w.close

    begin
      return r.read
    ensure
      Process.wait pid
    end
  end

  NULL_DEVICE = defined?(IO::NULL) ? IO::NULL : Gem.win_platform? ? 'NUL' : '/dev/null'


  def self.silent_system *command
    opt = {:out => NULL_DEVICE, :err => [:child, :out]}
    if Hash === command.last
      opt.update(command.last)
      cmds = command[0...-1]
    else
      cmds = command.dup
    end
    return system(*(cmds << opt))
  rescue TypeError
    require 'thread'

    @silent_mutex ||= Mutex.new

    null_device = NULL_DEVICE

    @silent_mutex.synchronize do
      begin
        stdout = STDOUT.dup
        stderr = STDERR.dup

        STDOUT.reopen null_device, 'w'
        STDERR.reopen null_device, 'w'

        return system(*command)
      ensure
        STDOUT.reopen stdout
        STDERR.reopen stderr
        stdout.close
        stderr.close
      end
    end
  end


  def self.traverse_parents directory
    return enum_for __method__, directory unless block_given?

    here = File.expand_path directory
    start = here

    Dir.chdir start

    begin
      loop do
        yield here

        Dir.chdir '..'

        return if Dir.pwd == here # toplevel

        here = Dir.pwd
      end
    ensure
      Dir.chdir start
    end
  end

end
