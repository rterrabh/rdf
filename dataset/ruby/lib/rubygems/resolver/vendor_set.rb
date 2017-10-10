
class Gem::Resolver::VendorSet < Gem::Resolver::Set


  attr_reader :specs # :nodoc:

  def initialize # :nodoc:
    super()

    @directories = {}
    @specs       = {}
  end


  def add_vendor_gem name, directory # :nodoc:
    gemspec = File.join directory, "#{name}.gemspec"

    spec = Gem::Specification.load gemspec

    raise Gem::GemNotFoundException,
          "unable to find #{gemspec} for gem #{name}" unless spec

    spec.full_gem_path = File.expand_path directory

    @specs[spec.name]  = spec
    @directories[spec] = directory

    spec
  end


  def find_all req
    @specs.values.select do |spec|
      req.match? spec
    end.map do |spec|
      source = Gem::Source::Vendor.new @directories[spec]
      Gem::Resolver::VendorSpecification.new self, spec, source
    end
  end


  def load_spec name, version, platform, source # :nodoc:
    @specs.fetch name
  end

  def pretty_print q # :nodoc:
    q.group 2, '[VendorSet', ']' do
      next if @directories.empty?
      q.breakable

      dirs = @directories.map do |spec, directory|
        "#{spec.full_name}: #{directory}"
      end

      q.seplist dirs do |dir|
        q.text dir
      end
    end
  end

end

