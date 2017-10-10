
class Gem::Resolver::APISet < Gem::Resolver::Set


  attr_reader :dep_uri # :nodoc:


  attr_reader :source


  attr_reader :uri


  def initialize dep_uri = 'https://rubygems.org/api/v1/dependencies'
    super()

    dep_uri = URI dep_uri unless URI === dep_uri # for ruby 1.8

    @dep_uri = dep_uri
    @uri     = dep_uri + '../..'

    @data   = Hash.new { |h,k| h[k] = [] }
    @source = Gem::Source.new @uri

    @to_fetch = []
  end


  def find_all req
    res = []

    return res unless @remote

    if @to_fetch.include?(req.name)
      prefetch_now
    end

    versions(req.name).each do |ver|
      if req.dependency.match? req.name, ver[:number]
        res << Gem::Resolver::APISpecification.new(self, ver)
      end
    end

    res
  end


  def prefetch reqs
    return unless @remote
    names = reqs.map { |r| r.dependency.name }
    needed = names - @data.keys - @to_fetch

    @to_fetch += needed
  end

  def prefetch_now # :nodoc:
    needed, @to_fetch = @to_fetch, []

    uri = @dep_uri + "?gems=#{needed.sort.join ','}"
    str = Gem::RemoteFetcher.fetcher.fetch_path uri

    loaded = []

    Marshal.load(str).each do |ver|
      name = ver[:name]

      @data[name] << ver
      loaded << name
    end

    (needed - loaded).each do |missing|
      @data[missing] = []
    end
  end

  def pretty_print q # :nodoc:
    q.group 2, '[APISet', ']' do
      q.breakable
      q.text "URI: #{@dep_uri}"

      q.breakable
      q.text 'gem names:'
      q.pp @data.keys
    end
  end


  def versions name # :nodoc:
    if @data.key?(name)
      return @data[name]
    end

    uri = @dep_uri + "?gems=#{name}"
    str = Gem::RemoteFetcher.fetcher.fetch_path uri

    Marshal.load(str).each do |ver|
      @data[ver[:name]] << ver
    end

    @data[name]
  end

end

