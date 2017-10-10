
require 'rubygems'
require 'rubygems/package'
begin
  gem 'rake'
rescue Gem::LoadError
end

require 'rake/packagetask'


class Gem::PackageTask < Rake::PackageTask


  attr_accessor :gem_spec


  def initialize(gem_spec)
    init gem_spec
    yield self if block_given?
    define if block_given?
  end


  def init(gem)
    super gem.full_name, :noversion
    @gem_spec = gem
    @package_files += gem_spec.files if gem_spec.files
  end


  def define
    super

    gem_file = File.basename gem_spec.cache_file
    gem_path = File.join package_dir, gem_file
    gem_dir  = File.join package_dir, gem_spec.full_name

    task :package => [:gem]

    directory package_dir
    directory gem_dir

    desc "Build the gem file #{gem_file}"
    task :gem => [gem_path]

    trace = Rake.application.options.trace
    Gem.configuration.verbose = trace

    file gem_path => [package_dir, gem_dir] + @gem_spec.files do
      chdir(gem_dir) do
        when_writing "Creating #{gem_spec.file_name}" do
          Gem::Package.build gem_spec

          verbose trace do
            mv gem_file, '..'
          end
        end
      end
    end
  end

end

