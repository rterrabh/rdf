
class Gem::Resolver::BestSet < Gem::Resolver::ComposedSet


  def initialize sources = Gem.sources
    super()

    @sources = sources
  end


  def pick_sets # :nodoc:
    @sources.each_source do |source|
      @sets << source.dependency_resolver_set
    end
  end

  def find_all req # :nodoc:
    pick_sets if @remote and @sets.empty?

    super
  rescue Gem::RemoteFetcher::FetchError => e
    replace_failed_api_set e

    retry
  end

  def prefetch reqs # :nodoc:
    pick_sets if @remote and @sets.empty?

    super
  end

  def pretty_print q # :nodoc:
    q.group 2, '[BestSet', ']' do
      q.breakable
      q.text 'sets:'

      q.breakable
      q.pp @sets
    end
  end


  def replace_failed_api_set error # :nodoc:
    uri = error.uri
    uri = URI uri unless URI === uri
    uri.query = nil

    raise error unless api_set = @sets.find { |set|
      Gem::Resolver::APISet === set and set.dep_uri == uri
    }

    index_set = Gem::Resolver::IndexSet.new api_set.source

    @sets.map! do |set|
      next set unless set == api_set
      index_set
    end
  end

end

