
class Gem::Resolver::GitSpecification < Gem::Resolver::SpecSpecification

  def == other # :nodoc:
    self.class === other and
      @set  == other.set and
      @spec == other.spec and
      @source == other.source
  end

  def add_dependency dependency # :nodoc:
    spec.dependencies << dependency
  end


  def install options = {}
    require 'rubygems/installer'

    installer = Gem::Installer.new '', options
    installer.spec = spec

    yield installer if block_given?

    installer.run_pre_install_hooks
    installer.build_extensions
    installer.run_post_build_hooks
    installer.generate_bin
    installer.run_post_install_hooks
  end

  def pretty_print q # :nodoc:
    q.group 2, '[GitSpecification', ']' do
      q.breakable
      q.text "name: #{name}"

      q.breakable
      q.text "version: #{version}"

      q.breakable
      q.text 'dependencies:'
      q.breakable
      q.pp dependencies

      q.breakable
      q.text "source:"
      q.breakable
      q.pp @source
    end
  end

end

