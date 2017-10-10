
class Gem::Resolver::LockSpecification < Gem::Resolver::Specification

  def initialize set, name, version, source, platform
    super()

    @name     = name
    @platform = platform
    @set      = set
    @source   = source
    @version  = version

    @dependencies = []
    @spec         = nil
  end


  def install options = {}
    destination = options[:install_dir] || Gem.dir

    if File.exist? File.join(destination, 'specifications', spec.spec_name) then
      yield nil
      return
    end

    super
  end


  def add_dependency dependency # :nodoc:
    @dependencies << dependency
  end

  def pretty_print q # :nodoc:
    q.group 2, '[LockSpecification', ']' do
      q.breakable
      q.text "name: #{@name}"

      q.breakable
      q.text "version: #{@version}"

      unless @platform == Gem::Platform::RUBY then
        q.breakable
        q.text "platform: #{@platform}"
      end

      unless @dependencies.empty? then
        q.breakable
        q.text 'dependencies:'
        q.breakable
        q.pp @dependencies
      end
    end
  end


  def spec
    @spec ||= Gem::Specification.find { |spec|
      spec.name == @name and spec.version == @version
    }

    @spec ||= Gem::Specification.new do |s|
      s.name     = @name
      s.version  = @version
      s.platform = @platform

      s.dependencies.concat @dependencies
    end
  end

end

