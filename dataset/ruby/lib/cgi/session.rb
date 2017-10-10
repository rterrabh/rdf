
require 'cgi'
require 'tmpdir'

class CGI

  class Session

    class NoSession < RuntimeError #:nodoc:
    end

    attr_reader :session_id, :new_session

    def Session::callback(dbman)  #:nodoc:
      Proc.new{
        dbman[0].close unless dbman.empty?
      }
    end

    def create_new_id
      require 'securerandom'
      begin
        session_id = SecureRandom.hex(16)
      rescue NotImplementedError
        require 'digest/md5'
        md5 = Digest::MD5::new
        now = Time::now
        md5.update(now.to_s)
        md5.update(String(now.usec))
        md5.update(String(rand(0)))
        md5.update(String($$))
        md5.update('foobar')
        session_id = md5.hexdigest
      end
      session_id
    end
    private :create_new_id

    def initialize(request, option={})
      @new_session = false
      session_key = option['session_key'] || '_session_id'
      session_id = option['session_id']
      unless session_id
        if option['new_session']
          session_id = create_new_id
          @new_session = true
        end
      end
      unless session_id
        if request.key?(session_key)
          session_id = request[session_key]
          session_id = session_id.read if session_id.respond_to?(:read)
        end
        unless session_id
          session_id, = request.cookies[session_key]
        end
        unless session_id
          unless option.fetch('new_session', true)
            raise ArgumentError, "session_key `%s' should be supplied"%session_key
          end
          session_id = create_new_id
          @new_session = true
        end
      end
      @session_id = session_id
      dbman = option['database_manager'] || FileStore
      begin
        @dbman = dbman::new(self, option)
      rescue NoSession
        unless option.fetch('new_session', true)
          raise ArgumentError, "invalid session_id `%s'"%session_id
        end
        session_id = @session_id = create_new_id unless session_id
        @new_session=true
        retry
      end
      #nodyna <instance_eval-1935> <IEV COMPLEX (private access)>
      request.instance_eval do
        @output_hidden = {session_key => session_id} unless option['no_hidden']
        @output_cookies =  [
          Cookie::new("name" => session_key,
          "value" => session_id,
          "expires" => option['session_expires'],
          "domain" => option['session_domain'],
          "secure" => option['session_secure'],
          "path" =>
          if option['session_path']
            option['session_path']
          elsif ENV["SCRIPT_NAME"]
            File::dirname(ENV["SCRIPT_NAME"])
          else
          ""
          end)
        ] unless option['no_cookies']
      end
      @dbprot = [@dbman]
      ObjectSpace::define_finalizer(self, Session::callback(@dbprot))
    end

    def [](key)
      @data ||= @dbman.restore
      @data[key]
    end

    def []=(key, val)
      @write_lock ||= true
      @data ||= @dbman.restore
      @data[key] = val
    end

    def update
      @dbman.update
    end

    def close
      @dbman.close
      @dbprot.clear
    end

    def delete
      @dbman.delete
      @dbprot.clear
    end

    class FileStore
      def initialize(session, option={})
        dir = option['tmpdir'] || Dir::tmpdir
        prefix = option['prefix'] || 'cgi_sid_'
        suffix = option['suffix'] || ''
        id = session.session_id
        require 'digest/md5'
        md5 = Digest::MD5.hexdigest(id)[0,16]
        @path = dir+"/"+prefix+md5+suffix
        if File::exist? @path
          @hash = nil
        else
          unless session.new_session
            raise CGI::Session::NoSession, "uninitialized session"
          end
          @hash = {}
        end
      end

      def restore
        unless @hash
          @hash = {}
          begin
            lockf = File.open(@path+".lock", "r")
            lockf.flock File::LOCK_SH
            f = File.open(@path, 'r')
            for line in f
              line.chomp!
              k, v = line.split('=',2)
              @hash[CGI::unescape(k)] = Marshal.restore(CGI::unescape(v))
            end
          ensure
            f.close unless f.nil?
            lockf.close if lockf
          end
        end
        @hash
      end

      def update
        return unless @hash
        begin
          lockf = File.open(@path+".lock", File::CREAT|File::RDWR, 0600)
          lockf.flock File::LOCK_EX
          f = File.open(@path+".new", File::CREAT|File::TRUNC|File::WRONLY, 0600)
          for k,v in @hash
            f.printf "%s=%s\n", CGI::escape(k), CGI::escape(String(Marshal.dump(v)))
          end
          f.close
          File.rename @path+".new", @path
        ensure
          f.close if f and !f.closed?
          lockf.close if lockf
        end
      end

      def close
        update
      end

      def delete
        File::unlink @path+".lock" rescue nil
        File::unlink @path+".new" rescue nil
        File::unlink @path rescue nil
      end
    end

    class MemoryStore
      GLOBAL_HASH_TABLE = {} #:nodoc:

      def initialize(session, option=nil)
        @session_id = session.session_id
        unless GLOBAL_HASH_TABLE.key?(@session_id)
          unless session.new_session
            raise CGI::Session::NoSession, "uninitialized session"
          end
          GLOBAL_HASH_TABLE[@session_id] = {}
        end
      end

      def restore
        GLOBAL_HASH_TABLE[@session_id]
      end

      def update
      end

      def close
      end

      def delete
        GLOBAL_HASH_TABLE.delete(@session_id)
      end
    end

    class NullStore
      def initialize(session, option=nil)
      end

      def restore
        {}
      end

      def update
      end

      def close
      end

      def delete
      end
    end
  end
end
