
require 'socket'
require 'fcntl'
require 'etc'

module WEBrick
  module Utils
    def set_non_blocking(io)
      flag = File::NONBLOCK
      if defined?(Fcntl::F_GETFL)
        flag |= io.fcntl(Fcntl::F_GETFL)
      end
      io.fcntl(Fcntl::F_SETFL, flag)
    end
    module_function :set_non_blocking

    def set_close_on_exec(io)
      if defined?(Fcntl::FD_CLOEXEC)
        io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      end
    end
    module_function :set_close_on_exec

    def su(user)
      if pw = Etc.getpwnam(user)
        Process::initgroups(user, pw.gid)
        Process::Sys::setgid(pw.gid)
        Process::Sys::setuid(pw.uid)
      else
        warn("WEBrick::Utils::su doesn't work on this platform")
      end
    end
    module_function :su

    def getservername
      host = Socket::gethostname
      begin
        Socket::gethostbyname(host)[0]
      rescue
        host
      end
    end
    module_function :getservername

    def create_listeners(address, port, logger=nil)
      unless port
        raise ArgumentError, "must specify port"
      end
      sockets = Socket.tcp_server_sockets(address, port)
      sockets = sockets.map {|s|
        s.autoclose = false
        ts = TCPServer.for_fd(s.fileno)
        s.close
        ts
      }
      return sockets
    end
    module_function :create_listeners

    RAND_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
                 "0123456789" +
                 "abcdefghijklmnopqrstuvwxyz"

    def random_string(len)
      rand_max = RAND_CHARS.bytesize
      ret = ""
      len.times{ ret << RAND_CHARS[rand(rand_max)] }
      ret
    end
    module_function :random_string


    require "thread"
    require "timeout"
    require "singleton"

    class TimeoutHandler
      include Singleton

      class Thread < ::Thread; end

      TimeoutMutex = Mutex.new # :nodoc:

      def TimeoutHandler.register(seconds, exception)
        TimeoutMutex.synchronize{
          instance.register(Thread.current, Time.now + seconds, exception)
        }
      end

      def TimeoutHandler.cancel(id)
        TimeoutMutex.synchronize{
          instance.cancel(Thread.current, id)
        }
      end

      def initialize
        @timeout_info = Hash.new
        Thread.start{
          while true
            now = Time.now
            @timeout_info.keys.each{|thread|
              ary = @timeout_info[thread]
              next unless ary
              ary.dup.each{|info|
                time, exception = *info
                interrupt(thread, info.object_id, exception) if time < now
              }
            }
            sleep 0.5
          end
        }
      end

      def interrupt(thread, id, exception)
        TimeoutMutex.synchronize{
          if cancel(thread, id) && thread.alive?
            thread.raise(exception, "execution timeout")
          end
        }
      end

      def register(thread, time, exception)
        @timeout_info[thread] ||= Array.new
        @timeout_info[thread] << [time, exception]
        return @timeout_info[thread].last.object_id
      end

      def cancel(thread, id)
        if ary = @timeout_info[thread]
          ary.delete_if{|info| info.object_id == id }
          if ary.empty?
            @timeout_info.delete(thread)
          end
          return true
        end
        return false
      end
    end

    def timeout(seconds, exception=Timeout::Error)
      return yield if seconds.nil? or seconds.zero?
      id = TimeoutHandler.register(seconds, exception)
      begin
        yield(seconds)
      ensure
        TimeoutHandler.cancel(id)
      end
    end
    module_function :timeout
  end
end
