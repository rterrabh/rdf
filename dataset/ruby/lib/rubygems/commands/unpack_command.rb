require 'rubygems/command'
require 'rubygems/installer'
require 'rubygems/version_option'
require 'rubygems/remote_fetcher'

class Gem::Commands::UnpackCommand < Gem::Command

  include Gem::VersionOption

  def initialize
    require 'fileutils'

    super 'unpack', 'Unpack an installed gem to the current directory',
          :version => Gem::Requirement.default,
          :target  => Dir.pwd

    add_option('--target=DIR',
               'target directory for unpacking') do |value, options|
      options[:target] = value
    end

    add_option('--spec', 'unpack the gem specification') do |value, options|
      options[:spec] = true
    end

    add_version_option
  end

  def arguments # :nodoc:
    "GEMNAME       name of gem to unpack"
  end

  def defaults_str # :nodoc:
    "--version '#{Gem::Requirement.default}'"
  end

  def description
    <<-EOF
The unpack command allows you to examine the contents of a gem or modify
them to help diagnose a bug.

You can add the contents of the unpacked gem to the load path using the
RUBYLIB environment variable or -I:

  $ gem unpack my_gem
  Unpacked gem: '.../my_gem-1.0'
  [edit my_gem-1.0/lib/my_gem.rb]
  $ ruby -Imy_gem-1.0/lib -S other_program

You can repackage an unpacked gem using the build command.  See the build
command help for an example.
    EOF
  end

  def usage # :nodoc:
    "#{program_name} GEMNAME"
  end


  def execute
    get_all_gem_names.each do |name|
      dependency = Gem::Dependency.new name, options[:version]
      path = get_path dependency

      unless path then
        alert_error "Gem '#{name}' not installed nor fetchable."
        next
      end

      if @options[:spec] then
        spec, metadata = get_metadata path

        if metadata.nil? then
          alert_error "--spec is unsupported on '#{name}' (old format gem)"
          next
        end

        spec_file = File.basename spec.spec_file

        open spec_file, 'w' do |io|
          io.write metadata
        end
      else
        basename = File.basename path, '.gem'
        target_dir = File.expand_path basename, options[:target]

        package = Gem::Package.new path
        package.extract_files target_dir

        say "Unpacked gem: '#{target_dir}'"
      end
    end
  end


  def find_in_cache(filename)
    Gem.path.each do |path|
      this_path = File.join(path, "cache", filename)
      return this_path if File.exist? this_path
    end

    return nil
  end


  def get_path dependency
    return dependency.name if dependency.name =~ /\.gem$/i

    specs = dependency.matching_specs

    selected = specs.max_by { |s| s.version }

    return Gem::RemoteFetcher.fetcher.download_to_cache(dependency) unless
      selected

    return unless dependency.name =~ /^#{selected.name}$/i


    path = find_in_cache File.basename selected.cache_file

    return Gem::RemoteFetcher.fetcher.download_to_cache(dependency) unless path

    path
  end


  def get_metadata path
    format = Gem::Package.new path
    spec = format.spec

    metadata = nil

    open path, Gem.binary_mode do |io|
      tar = Gem::Package::TarReader.new io
      tar.each_entry do |entry|
        case entry.full_name
        when 'metadata' then
          metadata = entry.read
        when 'metadata.gz' then
          metadata = Gem.gunzip entry.read
        end
      end
    end

    return spec, metadata
  end

end

