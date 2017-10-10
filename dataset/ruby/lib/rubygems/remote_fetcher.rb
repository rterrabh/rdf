require 'rubygems'
require 'rubygems/request'
require 'rubygems/uri_formatter'
require 'rubygems/user_interaction'
require 'rubygems/request/connection_pools'
require 'resolv'


class Gem::RemoteFetcher

  include Gem::UserInteraction


  class FetchError < Gem::Exception


    attr_accessor :uri

    def initialize(message, uri)
      super message
      @uri = uri
    end

    def to_s # :nodoc:
      "#{super} (#{uri})"
    end

  end


  class UnknownHostError < FetchError
  end

  @fetcher = nil


  def self.fetcher
    @fetcher ||= self.new Gem.configuration[:http_proxy]
  end


  def initialize(proxy=nil, dns=Resolv::DNS.new)
    require 'net/http'
    require 'stringio'
    require 'time'
    require 'uri'

    Socket.do_not_reverse_lookup = true

    @proxy = proxy
    @pools = {}
    @pool_lock = Mutex.new
    @cert_files = Gem::Request.get_cert_files

    @dns = dns
  end


  def api_endpoint(uri)
    host = uri.host

    begin
      res = @dns.getresource "_rubygems._tcp.#{host}",
                             Resolv::DNS::Resource::IN::SRV
    rescue Resolv::ResolvError
      uri
    else
      target = res.target.to_s.strip

      if /\.#{Regexp.quote(host)}\z/ =~ target
        return URI.parse "#{uri.scheme}://#{target}#{uri.path}"
      end

      uri
    end
  end


  def download_to_cache dependency
    found, _ = Gem::SpecFetcher.fetcher.spec_for_dependency dependency

    return if found.empty?

    spec, source = found.max_by { |(s,_)| s.version }

    download spec, source.uri.to_s
  end


  def download(spec, source_uri, install_dir = Gem.dir)
    cache_dir =
      if Dir.pwd == install_dir then # see fetch_command
        install_dir
      elsif File.writable? install_dir then
        File.join install_dir, "cache"
      else
        File.join Gem.user_dir, "cache"
      end

    gem_file_name = File.basename spec.cache_file
    local_gem_path = File.join cache_dir, gem_file_name

    FileUtils.mkdir_p cache_dir rescue nil unless File.exist? cache_dir

    unless source_uri.is_a?(URI::Generic)
      begin
        source_uri = URI.parse(source_uri)
      rescue
        source_uri = URI.parse(URI.const_defined?(:DEFAULT_PARSER) ?
                               URI::DEFAULT_PARSER.escape(source_uri.to_s) :
                               URI.escape(source_uri.to_s))
      end
    end

    scheme = source_uri.scheme

    scheme = nil if scheme =~ /^[a-z]$/i

    case scheme
    when 'http', 'https', 's3' then
      unless File.exist? local_gem_path then
        begin
          verbose "Downloading gem #{gem_file_name}"

          remote_gem_path = source_uri + "gems/#{gem_file_name}"

          self.cache_update_path remote_gem_path, local_gem_path
        rescue Gem::RemoteFetcher::FetchError
          raise if spec.original_platform == spec.platform

          alternate_name = "#{spec.original_name}.gem"

          verbose "Failed, downloading gem #{alternate_name}"

          remote_gem_path = source_uri + "gems/#{alternate_name}"

          self.cache_update_path remote_gem_path, local_gem_path
        end
      end
    when 'file' then
      begin
        path = source_uri.path
        path = File.dirname(path) if File.extname(path) == '.gem'

        remote_gem_path = correct_for_windows_path(File.join(path, 'gems', gem_file_name))

        FileUtils.cp(remote_gem_path, local_gem_path)
      rescue Errno::EACCES
        local_gem_path = source_uri.to_s
      end

      verbose "Using local gem #{local_gem_path}"
    when nil then # TODO test for local overriding cache
      source_path = if Gem.win_platform? && source_uri.scheme &&
                       !source_uri.path.include?(':') then
                      "#{source_uri.scheme}:#{source_uri.path}"
                    else
                      source_uri.path
                    end

      source_path = Gem::UriFormatter.new(source_path).unescape

      begin
        FileUtils.cp source_path, local_gem_path unless
          File.identical?(source_path, local_gem_path)
      rescue Errno::EACCES
        local_gem_path = source_uri.to_s
      end

      verbose "Using local gem #{local_gem_path}"
    else
      raise ArgumentError, "unsupported URI scheme #{source_uri.scheme}"
    end

    local_gem_path
  end


  def fetch_file uri, *_
    Gem.read_binary correct_for_windows_path uri.path
  end


  def fetch_http uri, last_modified = nil, head = false, depth = 0
    fetch_type = head ? Net::HTTP::Head : Net::HTTP::Get
    response   = request uri, fetch_type, last_modified

    case response
    when Net::HTTPOK, Net::HTTPNotModified then
      response.uri = uri if response.respond_to? :uri
      head ? response : response.body
    when Net::HTTPMovedPermanently, Net::HTTPFound, Net::HTTPSeeOther,
         Net::HTTPTemporaryRedirect then
      raise FetchError.new('too many redirects', uri) if depth > 10

      location = URI.parse response['Location']

      if https?(uri) && !https?(location)
        raise FetchError.new("redirecting to non-https resource: #{location}", uri)
      end

      fetch_http(location, last_modified, head, depth + 1)
    else
      raise FetchError.new("bad response #{response.message} #{response.code}", uri)
    end
  end

  alias :fetch_https :fetch_http


  def fetch_path(uri, mtime = nil, head = false)
    uri = URI.parse uri unless URI::Generic === uri

    raise ArgumentError, "bad uri: #{uri}" unless uri

    unless uri.scheme
      raise ArgumentError, "uri scheme is invalid: #{uri.scheme.inspect}"
    end

    #nodyna <send-2329> <SD COMPLEX (change-prone variables)>
    data = send "fetch_#{uri.scheme}", uri, mtime, head

    if data and !head and uri.to_s =~ /\.gz$/
      begin
        data = Gem.gunzip data
      rescue Zlib::GzipFile::Error
        raise FetchError.new("server did not return a valid file", uri.to_s)
      end
    end

    data
  rescue FetchError
    raise
  rescue Timeout::Error
    raise UnknownHostError.new('timed out', uri.to_s)
  rescue IOError, SocketError, SystemCallError => e
    if e.message =~ /getaddrinfo/
      raise UnknownHostError.new('no such name', uri.to_s)
    else
      raise FetchError.new("#{e.class}: #{e}", uri.to_s)
    end
  end

  def fetch_s3(uri, mtime = nil, head = false)
    public_uri = sign_s3_url(uri)
    fetch_https public_uri, mtime, head
  end


  def cache_update_path uri, path = nil, update = true
    mtime = path && File.stat(path).mtime rescue nil

    data = fetch_path(uri, mtime)

    if data == nil # indicates the server returned 304 Not Modified
      return Gem.read_binary(path)
    end

    if update and path
      open(path, 'wb') do |io|
        io.flock(File::LOCK_EX)
        io.write data
      end
    end

    data
  end


  def fetch_size(uri) # TODO: phase this out
    response = fetch_path(uri, nil, true)

    response['content-length'].to_i
  end

  def correct_for_windows_path(path)
    if path[0].chr == '/' && path[1].chr =~ /[a-z]/i && path[2].chr == ':'
      path[1..-1]
    else
      path
    end
  end


  def request(uri, request_class, last_modified = nil)
    proxy = proxy_for @proxy, uri
    pool  = pools_for(proxy).pool_for uri

    request = Gem::Request.new uri, request_class, last_modified, pool

    request.fetch do |req|
      yield req if block_given?
    end
  end

  def https?(uri)
    uri.scheme.downcase == 'https'
  end

  def close_all
    @pools.each_value {|pool| pool.close_all}
  end

  protected

  def sign_s3_url(uri, expiration = nil)
    require 'base64'
    require 'openssl'

    unless uri.user && uri.password
      raise FetchError.new("credentials needed in s3 source, like s3://key:secret@bucket-name/", uri.to_s)
    end

    expiration ||= s3_expiration
    canonical_path = "/#{uri.host}#{uri.path}"
    payload = "GET\n\n\n#{expiration}\n#{canonical_path}"
    digest = OpenSSL::HMAC.digest('sha1', uri.password, payload)
    signature = Base64.encode64(digest).gsub("\n", '').gsub(/[\+\/=]/) { |c| BASE64_URI_TRANSLATE[c] }
    URI.parse("https://#{uri.host}.s3.amazonaws.com#{uri.path}?AWSAccessKeyId=#{uri.user}&Expires=#{expiration}&Signature=#{signature}")
  end

  def s3_expiration
    (Time.now + 3600).to_i # one hour from now
  end

  BASE64_URI_TRANSLATE = { '+' => '%2B', '/' => '%2F', '=' => '%3D' }.freeze

  private

  def proxy_for proxy, uri
    Gem::Request.proxy_uri(proxy || Gem::Request.get_proxy_from_env(uri.scheme))
  end

  def pools_for proxy
    @pool_lock.synchronize do
      @pools[proxy] ||= Gem::Request::ConnectionPools.new proxy, @cert_files
    end
  end
end

