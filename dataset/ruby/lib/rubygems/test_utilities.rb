require 'tempfile'
require 'rubygems'
require 'rubygems/remote_fetcher'


class Gem::FakeFetcher

  attr_reader :data
  attr_reader :last_request
  attr_reader :api_endpoints
  attr_accessor :paths

  def initialize
    @data = {}
    @paths = []
    @api_endpoints = {}
  end

  def api_endpoint(uri)
    @api_endpoints[uri] || uri
  end

  def find_data(path)
    return File.read path.path if URI === path and 'file' == path.scheme

    if URI === path and "URI::#{path.scheme.upcase}" != path.class.name then
      raise ArgumentError,
        "mismatch for scheme #{path.scheme} and class #{path.class}"
    end

    path = path.to_s
    @paths << path
    raise ArgumentError, 'need full URI' unless path =~ %r'^https?://'

    unless @data.key? path then
      raise Gem::RemoteFetcher::FetchError.new("no data for #{path}", path)
    end

    @data[path]
  end

  def fetch_path path, mtime = nil, head = false
    data = find_data(path)

    if data.respond_to?(:call) then
      data.call
    else
      if path.to_s =~ /gz$/ and not data.nil? and not data.empty? then
        data = Gem.gunzip data
      end

      data
    end
  end

  def cache_update_path uri, path = nil, update = true
    if data = fetch_path(uri)
      open(path, 'wb') { |io| io.write data } if path and update
      data
    else
      Gem.read_binary(path) if path
    end
  end

  def open_uri_or_path(path)
    data = find_data(path)
    body, code, msg = data

    #nodyna <send-2322> <SD EASY (private methods)>
    response = Net::HTTPResponse.send(:response_class, code.to_s).new("1.0", code.to_s, msg)
    #nodyna <instance_variable_set-2323> <not yet classified>
    response.instance_variable_set(:@body, body)
    #nodyna <instance_variable_set-2324> <not yet classified>
    response.instance_variable_set(:@read, true)
    response
  end

  def request(uri, request_class, last_modified = nil)
    data = find_data(uri)
    body, code, msg = data

    @last_request = request_class.new uri.request_uri
    yield @last_request if block_given?

    #nodyna <send-2325> <SD EASY (private methods)>
    response = Net::HTTPResponse.send(:response_class, code.to_s).new("1.0", code.to_s, msg)
    #nodyna <instance_variable_set-2326> <not yet classified>
    response.instance_variable_set(:@body, body)
    #nodyna <instance_variable_set-2327> <not yet classified>
    response.instance_variable_set(:@read, true)
    response
  end

  def pretty_print q # :nodoc:
    q.group 2, '[FakeFetcher', ']' do
      q.breakable
      q.text 'URIs:'

      q.breakable
      q.pp @data.keys

      unless @api_endpoints.empty? then
        q.breakable
        q.text 'API endpoints:'

        q.breakable
        q.pp @api_endpoints.keys
      end
    end
  end

  def fetch_size(path)
    path = path.to_s
    @paths << path

    raise ArgumentError, 'need full URI' unless path =~ %r'^http://'

    unless @data.key? path then
      raise Gem::RemoteFetcher::FetchError.new("no data for #{path}", path)
    end

    data = @data[path]

    data.respond_to?(:call) ? data.call : data.length
  end

  def download spec, source_uri, install_dir = Gem.dir
    name = File.basename spec.cache_file
    path = if Dir.pwd == install_dir then # see fetch_command
             install_dir
           else
             File.join install_dir, "cache"
           end

    path = File.join path, name

    if source_uri =~ /^http/ then
      File.open(path, "wb") do |f|
        f.write fetch_path(File.join(source_uri, "gems", name))
      end
    else
      FileUtils.cp source_uri, path
    end

    path
  end

  def download_to_cache dependency
    found, _ = Gem::SpecFetcher.fetcher.spec_for_dependency dependency

    return if found.empty?

    spec, source = found.first

    download spec, source.uri.to_s
  end

end

class Gem::RemoteFetcher

  def self.fetcher=(fetcher)
    @fetcher = fetcher
  end

end


class Gem::TestCase::SpecFetcherSetup


  def self.declare test, repository
    setup = new test, repository

    yield setup

    setup.execute
  end

  def initialize test, repository # :nodoc:
    @test       = test
    @repository = repository

    @gems       = {}
    @installed  = []
    @operations = []
  end


  def clear
    @operations << [:clear]
  end


  def created_specs
    created = {}

    @gems.keys.each do |spec|
      created[spec.full_name] = spec
    end

    created
  end


  def execute # :nodoc:
    execute_operations

    setup_fetcher

    created_specs
  end

  def execute_operations # :nodoc:
    @operations.each do |operation, *arguments|
      case operation
      when :clear then
        @test.util_clear_gems
        @installed.clear
      when :gem then
        spec, gem = @test.util_gem(*arguments, &arguments.pop)

        write_spec spec

        @gems[spec] = gem
        @installed << spec
      when :spec then
        spec = @test.util_spec(*arguments, &arguments.pop)

        write_spec spec

        @gems[spec] = nil
        @installed << spec
      end
    end
  end


  def gem name, version, dependencies = nil, &block
    @operations << [:gem, name, version, dependencies, block]
  end


  def legacy_platform
    spec 'pl', 1 do |s|
      s.platform = Gem::Platform.new 'i386-linux'
      #nodyna <instance_variable_set-2328> <not yet classified>
      s.instance_variable_set :@original_platform, 'i386-linux'
    end
  end

  def setup_fetcher # :nodoc:
    require 'zlib'
    require 'socket'
    require 'rubygems/remote_fetcher'

    unless @test.fetcher then
      @test.fetcher = Gem::FakeFetcher.new
      Gem::RemoteFetcher.fetcher = @test.fetcher
    end

    Gem::Specification.reset

    begin
      gem_repo, @test.gem_repo = @test.gem_repo, @repository
      @test.uri = URI @repository

      @test.util_setup_spec_fetcher(*@gems.keys)
    ensure
      @test.gem_repo = gem_repo
      @test.uri = URI gem_repo
    end

    Gem::Specification.reset
    Gem::Specification.add_specs(*@installed)

    @gems.each do |spec, gem|
      next unless gem

      @test.fetcher.data["#{@repository}gems/#{spec.file_name}"] =
        Gem.read_binary(gem)

      FileUtils.cp gem, spec.cache_file
    end
  end


  def spec name, version, dependencies = nil, &block
    @operations << [:spec, name, version, dependencies, block]
  end

  def write_spec spec # :nodoc:
    open spec.spec_file, 'w' do |io|
      io.write spec.to_ruby_for_cache
    end
  end

end


class TempIO < Tempfile


  def initialize(string = '')
    super "TempIO"
    binmode
    write string
    rewind
  end


  def string
    flush
    Gem.read_binary path
  end
end

