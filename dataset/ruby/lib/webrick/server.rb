
require 'thread'
require 'socket'
require 'webrick/config'
require 'webrick/log'

module WEBrick


  class ServerError < StandardError; end


  class SimpleServer


    def SimpleServer.start
      yield
    end
  end


  class Daemon


    def Daemon.start
      exit!(0) if fork
      Process::setsid
      exit!(0) if fork
      Dir::chdir("/")
      File::umask(0)
      STDIN.reopen("/dev/null")
      STDOUT.reopen("/dev/null", "w")
      STDERR.reopen("/dev/null", "w")
      yield if block_given?
    end
  end


  class GenericServer


    attr_reader :status


    attr_reader :config


    attr_reader :logger


    attr_reader :tokens


    attr_reader :listeners


    def initialize(config={}, default=Config::General)
      @config = default.dup.update(config)
      @status = :Stop
      @config[:Logger] ||= Log::new
      @logger = @config[:Logger]

      @tokens = SizedQueue.new(@config[:MaxClients])
      @config[:MaxClients].times{ @tokens.push(nil) }

      webrickv = WEBrick::VERSION
      rubyv = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
      @logger.info("WEBrick #{webrickv}")
      @logger.info("ruby #{rubyv}")

      @listeners = []
      @shutdown_pipe = nil
      unless @config[:DoNotListen]
        if @config[:Listen]
          warn(":Listen option is deprecated; use GenericServer#listen")
        end
        listen(@config[:BindAddress], @config[:Port])
        if @config[:Port] == 0
          @config[:Port] = @listeners[0].addr[1]
        end
      end
    end


    def [](key)
      @config[key]
    end


    def listen(address, port)
      @listeners += Utils::create_listeners(address, port, @logger)
      setup_shutdown_pipe
    end


    def start(&block)
      raise ServerError, "already started." if @status != :Stop
      server_type = @config[:ServerType] || SimpleServer

      server_type.start{
        @logger.info \
          "#{self.class}#start: pid=#{$$} port=#{@config[:Port]}"
        call_callback(:StartCallback)

        shutdown_pipe = @shutdown_pipe

        thgroup = ThreadGroup.new
        @status = :Running
        begin
          while @status == :Running
            begin
              if svrs = IO.select([shutdown_pipe[0], *@listeners], nil, nil, 2.0)
                if svrs[0].include? shutdown_pipe[0]
                  break
                end
                svrs[0].each{|svr|
                  @tokens.pop          # blocks while no token is there.
                  if sock = accept_client(svr)
                    sock.do_not_reverse_lookup = config[:DoNotReverseLookup]
                    th = start_thread(sock, &block)
                    th[:WEBrickThread] = true
                    thgroup.add(th)
                  else
                    @tokens.push(nil)
                  end
                }
              end
            rescue Errno::EBADF, Errno::ENOTSOCK, IOError => ex
            rescue StandardError => ex
              msg = "#{ex.class}: #{ex.message}\n\t#{ex.backtrace[0]}"
              @logger.error msg
            rescue Exception => ex
              @logger.fatal ex
              raise
            end
          end
        ensure
          cleanup_shutdown_pipe(shutdown_pipe)
          cleanup_listener
          @status = :Shutdown
          @logger.info "going to shutdown ..."
          thgroup.list.each{|th| th.join if th[:WEBrickThread] }
          call_callback(:StopCallback)
          @logger.info "#{self.class}#start done."
          @status = :Stop
        end
      }
    end


    def stop
      if @status == :Running
        @status = :Shutdown
      end
    end


    def shutdown
      stop

      shutdown_pipe = @shutdown_pipe # another thread may modify @shutdown_pipe.
      if shutdown_pipe
        if !shutdown_pipe[1].closed?
          begin
            shutdown_pipe[1].close
          rescue IOError # closed by another thread.
          end
        end
      end
    end


    def run(sock)
      @logger.fatal "run() must be provided by user."
    end

    private



    def accept_client(svr)
      sock = nil
      begin
        sock = svr.accept
        sock.sync = true
        Utils::set_non_blocking(sock)
        Utils::set_close_on_exec(sock)
      rescue Errno::ECONNRESET, Errno::ECONNABORTED,
             Errno::EPROTO, Errno::EINVAL
      rescue StandardError => ex
        msg = "#{ex.class}: #{ex.message}\n\t#{ex.backtrace[0]}"
        @logger.error msg
      end
      return sock
    end


    def start_thread(sock, &block)
      Thread.start{
        begin
          Thread.current[:WEBrickSocket] = sock
          begin
            addr = sock.peeraddr
            @logger.debug "accept: #{addr[3]}:#{addr[1]}"
          rescue SocketError
            @logger.debug "accept: <address unknown>"
            raise
          end
          call_callback(:AcceptCallback, sock)
          block ? block.call(sock) : run(sock)
        rescue Errno::ENOTCONN
          @logger.debug "Errno::ENOTCONN raised"
        rescue ServerError => ex
          msg = "#{ex.class}: #{ex.message}\n\t#{ex.backtrace[0]}"
          @logger.error msg
        rescue Exception => ex
          @logger.error ex
        ensure
          @tokens.push(nil)
          Thread.current[:WEBrickSocket] = nil
          if addr
            @logger.debug "close: #{addr[3]}:#{addr[1]}"
          else
            @logger.debug "close: <address unknown>"
          end
          sock.close unless sock.closed?
        end
      }
    end


    def call_callback(callback_name, *args)
      if cb = @config[callback_name]
        cb.call(*args)
      end
    end

    def setup_shutdown_pipe
      if !@shutdown_pipe
        @shutdown_pipe = IO.pipe
      end
      @shutdown_pipe
    end

    def cleanup_shutdown_pipe(shutdown_pipe)
      @shutdown_pipe = nil
      shutdown_pipe.each {|io|
        if !io.closed?
          begin
            io.close
          rescue IOError # another thread closed io.
          end
        end
      }
    end

    def cleanup_listener
      @listeners.each{|s|
        if @logger.debug?
          addr = s.addr
          @logger.debug("close TCPSocket(#{addr[2]}, #{addr[1]})")
        end
        begin
          s.shutdown
        rescue Errno::ENOTCONN
          s.close
        else
          unless @config[:ShutdownSocketWithoutClose]
            s.close
          end
        end
      }
      @listeners.clear
    end
  end    # end of GenericServer
end
