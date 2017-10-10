
require 'webrick/httpauth/userdb'
require 'webrick/httpauth/basicauth'
require 'tempfile'

module WEBrick
  module HTTPAuth


    class Htpasswd
      include UserDB


      def initialize(path)
        @path = path
        @mtime = Time.at(0)
        @passwd = Hash.new
        @auth_type = BasicAuth
        open(@path,"a").close unless File::exist?(@path)
        reload
      end


      def reload
        mtime = File::mtime(@path)
        if mtime > @mtime
          @passwd.clear
          open(@path){|io|
            while line = io.gets
              line.chomp!
              case line
              when %r!\A[^:]+:[a-zA-Z0-9./]{13}\z!
                user, pass = line.split(":")
              when /:\$/, /:{SHA}/
                raise NotImplementedError,
                      'MD5, SHA1 .htpasswd file not supported'
              else
                raise StandardError, 'bad .htpasswd file'
              end
              @passwd[user] = pass
            end
          }
          @mtime = mtime
        end
      end


      def flush(output=nil)
        output ||= @path
        tmp = Tempfile.create("htpasswd", File::dirname(output))
        renamed = false
        begin
          each{|item| tmp.puts(item.join(":")) }
          tmp.close
          File::rename(tmp.path, output)
          renamed = true
        ensure
          tmp.close if !tmp.closed?
          File.unlink(tmp.path) if !renamed
        end
      end


      def get_passwd(realm, user, reload_db)
        reload() if reload_db
        @passwd[user]
      end


      def set_passwd(realm, user, pass)
        @passwd[user] = make_passwd(realm, user, pass)
      end


      def delete_passwd(realm, user)
        @passwd.delete(user)
      end


      def each # :yields: [user, password]
        @passwd.keys.sort.each{|user|
          yield([user, @passwd[user]])
        }
      end
    end
  end
end
