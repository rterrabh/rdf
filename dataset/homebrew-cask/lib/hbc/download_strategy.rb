require 'cgi'


class Hbc::AbstractDownloadStrategy
  attr_reader :cask, :name, :url, :uri_object, :version

  def initialize(cask, command=Hbc::SystemCommand)
    @cask       = cask
    @command    = command
    @name       = cask.token
    @url        = cask.url.to_s
    @uri_object = cask.url
    @version    = cask.version
  end

  def fetch; end
  def cached_location; end
  def clear_cache; end
end

require 'vendor/homebrew-fork/download_strategy'

class Hbc::CurlDownloadStrategy < Hbc::HbCurlDownloadStrategy

  def _fetch
    odebug "Calling curl with args #{curl_args.utf8_inspect}"
    curl(*curl_args)
  end

  def fetch
    super
    tarball_path
  end

  private

  def curl_args
    default_curl_args.tap do |args|
      args.concat(user_agent_args)
      args.concat(cookies_args)
      args.concat(referer_args)
    end
  end

  def default_curl_args
    [url, '-C', downloaded_size, '-o', temporary_path]
  end

  def user_agent_args
    if uri_object.user_agent
      ['-A', uri_object.user_agent]
    else
      []
    end
  end

  def cookies_args
    if uri_object.cookies
      [
        '-b',
        uri_object.cookies.sort_by{ |key, value| key.to_s }.map do |key, value|
          "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
        end.join(';')
      ]
    else
      []
    end
  end

  def referer_args
    if uri_object.referer
      ['-e',  uri_object.referer]
    else
      []
    end
  end
end

class Hbc::CurlPostDownloadStrategy < Hbc::CurlDownloadStrategy

  def curl_args
    super
    default_curl_args.concat(post_args)
  end

  def post_args
    if uri_object.data
      uri_object.data.sort_by{ |key, value| key.to_s }.map do |key, value|
        ['-d', "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"]
      end.flatten()
    else
      ['-X', 'POST']
    end
  end
end

class Hbc::SubversionDownloadStrategy < Hbc::HbSubversionDownloadStrategy

  def fetch
    if tarball_path.exist?
      puts "Already downloaded: #{tarball_path}"
    else
      super
      compress
    end
    tarball_path
  end

  def fetch_repo target, url, revision=uri_object.revision, ignore_externals=false
    svncommand = target.directory? ? 'up' : 'checkout'
    args = [svncommand]

    args << '--force' unless MacOS.release == :leopard

    args.concat(%w[--config-option config:miscellany:use-commit-times=yes])

    if uri_object.trust_cert
      args << '--trust-server-cert'
      args << '--non-interactive'
    end

    args << url unless target.directory?
    args << target
    args << '-r' << revision if revision
    args << '--ignore-externals' if ignore_externals
    @command.run!('/usr/bin/svn',
                  :args => args,
                  :print_stderr => false)
  end

  def tarball_path
    @tarball_path ||= cached_location.dirname.join(cached_location.basename.to_s + "-#{@cask.version}.tar")
  end

  private


  def compress
    Dir.chdir(cached_location) do
      @command.run!('/usr/bin/tar', :args => ['-s/^\.//', '--exclude', '.svn', '-cf', Pathname.new(tarball_path), '--', '.'],
                                    :print_stderr => false)
    end
    clear_cache
  end
end
