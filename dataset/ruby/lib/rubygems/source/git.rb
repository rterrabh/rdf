require 'digest'
require 'rubygems/util'


class Gem::Source::Git < Gem::Source


  attr_reader :name


  attr_reader :reference


  attr_accessor :remote


  attr_reader :repository


  attr_accessor :root_dir


  attr_reader :need_submodules


  def initialize name, repository, reference, submodules = false
    super repository

    @name            = name
    @repository      = repository
    @reference       = reference
    @need_submodules = submodules

    @remote   = true
    @root_dir = Gem.dir
    @git      = ENV['git'] || 'git'
  end

  def <=> other
    case other
    when Gem::Source::Git then
      0
    when Gem::Source::Vendor,
         Gem::Source::Lock then
      -1
    when Gem::Source then
      1
    else
      nil
    end
  end

  def == other # :nodoc:
    super and
      @name            == other.name and
      @repository      == other.repository and
      @reference       == other.reference and
      @need_submodules == other.need_submodules
  end


  def checkout # :nodoc:
    cache

    return false unless File.exist? repo_cache_dir

    unless File.exist? install_dir then
      system @git, 'clone', '--quiet', '--no-checkout',
             repo_cache_dir, install_dir
    end

    Dir.chdir install_dir do
      system @git, 'fetch', '--quiet', '--force', '--tags', install_dir

      success = system @git, 'reset', '--quiet', '--hard', rev_parse

      success &&=
        Gem::Util.silent_system @git, 'submodule', 'update',
               '--quiet', '--init', '--recursive' if @need_submodules

      success
    end
  end


  def cache # :nodoc:
    return unless @remote

    if File.exist? repo_cache_dir then
      Dir.chdir repo_cache_dir do
        system @git, 'fetch', '--quiet', '--force', '--tags',
               @repository, 'refs/heads/*:refs/heads/*'
      end
    else
      system @git, 'clone', '--quiet', '--bare', '--no-hardlinks',
             @repository, repo_cache_dir
    end
  end


  def base_dir # :nodoc:
    File.join @root_dir, 'bundler'
  end


  def dir_shortref # :nodoc:
    rev_parse[0..11]
  end


  def download full_spec, path # :nodoc:
  end


  def install_dir # :nodoc:
    return unless File.exist? repo_cache_dir

    File.join base_dir, 'gems', "#{@name}-#{dir_shortref}"
  end

  def pretty_print q # :nodoc:
    q.group 2, '[Git: ', ']' do
      q.breakable
      q.text @repository

      q.breakable
      q.text @reference
    end
  end


  def repo_cache_dir # :nodoc:
    File.join @root_dir, 'cache', 'bundler', 'git', "#{@name}-#{uri_hash}"
  end


  def rev_parse # :nodoc:
    hash = nil

    Dir.chdir repo_cache_dir do
      hash = Gem::Util.popen(@git, 'rev-parse', @reference).strip
    end

    raise Gem::Exception,
          "unable to find reference #{@reference} in #{@repository}" unless
            $?.success?

    hash
  end


  def specs
    checkout

    return [] unless install_dir

    Dir.chdir install_dir do
      Dir['{,*,*/*}.gemspec'].map do |spec_file|
        directory = File.dirname spec_file
        file      = File.basename spec_file

        Dir.chdir directory do
          spec = Gem::Specification.load file
          if spec then
            spec.base_dir = base_dir

            spec.extension_dir =
              File.join base_dir, 'extensions', Gem::Platform.local.to_s,
                Gem.extension_api_version, "#{name}-#{dir_shortref}"

            spec.full_gem_path = File.dirname spec.loaded_from if spec
          end
          spec
        end
      end.compact
    end
  end


  def uri_hash # :nodoc:
    normalized =
      if @repository =~ %r%^\w+://(\w+@)?% then
        uri = URI(@repository).normalize.to_s.sub %r%/$%,''
        uri.sub(/\A(\w+)/) { $1.downcase }
      else
        @repository
      end

    Digest::SHA1.hexdigest normalized
  end

end

