require 'rubygems'
require 'rubygems/user_interaction'


class Gem::Doctor

  include Gem::UserInteraction


  REPOSITORY_EXTENSION_MAP = [ # :nodoc:
    ['specifications', '.gemspec'],
    ['build_info',     '.info'],
    ['cache',          '.gem'],
    ['doc',            ''],
    ['extensions',     ''],
    ['gems',           ''],
  ]

  missing =
    Gem::REPOSITORY_SUBDIRECTORIES.sort -
      REPOSITORY_EXTENSION_MAP.map { |(k,_)| k }.sort

  raise "Update REPOSITORY_EXTENSION_MAP, missing: #{missing.join ', '}" unless
    missing.empty?


  def initialize gem_repository, dry_run = false
    @gem_repository = gem_repository
    @dry_run        = dry_run

    @installed_specs = nil
  end


  def installed_specs # :nodoc:
    @installed_specs ||= Gem::Specification.map { |s| s.full_name }
  end


  def gem_repository?
    not installed_specs.empty?
  end


  def doctor
    @orig_home = Gem.dir
    @orig_path = Gem.path

    say "Checking #{@gem_repository}"

    Gem.use_paths @gem_repository.to_s

    unless gem_repository? then
      say 'This directory does not appear to be a RubyGems repository, ' +
          'skipping'
      say
      return
    end

    doctor_children

    say
  ensure
    Gem.use_paths @orig_home, *@orig_path
  end


  def doctor_children # :nodoc:
    REPOSITORY_EXTENSION_MAP.each do |sub_directory, extension|
      doctor_child sub_directory, extension
    end
  end


  def doctor_child sub_directory, extension # :nodoc:
    directory = File.join(@gem_repository, sub_directory)

    Dir.entries(directory).sort.each do |ent|
      next if ent == "." || ent == ".."

      child = File.join(directory, ent)
      next unless File.exist?(child)

      basename = File.basename(child, extension)
      next if installed_specs.include? basename
      next if /^rubygems-\d/ =~ basename
      next if 'specifications' == sub_directory and 'default' == basename

      type = File.directory?(child) ? 'directory' : 'file'

      action = if @dry_run then
                 'Extra'
               else
                 FileUtils.rm_r(child)
                 'Removed'
               end

      say "#{action} #{type} #{sub_directory}/#{File.basename(child)}"
    end
  rescue Errno::ENOENT
  end

end

