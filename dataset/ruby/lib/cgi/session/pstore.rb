
require 'cgi/session'
require 'pstore'

class CGI
  class Session
    class PStore
      def initialize(session, option={})
        dir = option['tmpdir'] || Dir::tmpdir
        prefix = option['prefix'] || ''
        id = session.session_id
        require 'digest/md5'
        md5 = Digest::MD5.hexdigest(id)[0,16]
        path = dir+"/"+prefix+md5
        path.untaint
        if File::exist?(path)
          @hash = nil
        else
          unless session.new_session
            raise CGI::Session::NoSession, "uninitialized session"
          end
          @hash = {}
        end
        @p = ::PStore.new(path)
        @p.transaction do |p|
          File.chmod(0600, p.path)
        end
      end

      def restore
        unless @hash
          @p.transaction do
            @hash = @p['hash'] || {}
          end
        end
        @hash
      end

      def update
        @p.transaction do
          @p['hash'] = @hash
        end
      end

      def close
        update
      end

      def delete
        path = @p.path
        File::unlink path
      end

    end
  end
end
