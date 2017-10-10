require 'set'

module Jekyll
  class Cleaner
    attr_reader :site

    def initialize(site)
      @site = site
    end

    def cleanup!
      FileUtils.rm_rf(obsolete_files)
      FileUtils.rm_rf(metadata_file) if @site.full_rebuild?
    end

    private

    def obsolete_files
      (existing_files - new_files - new_dirs + replaced_files).to_a
    end

    def metadata_file
      [site.regenerator.metadata_file]
    end

    def existing_files
      files = Set.new
      regex = keep_file_regex
      dirs = keep_dirs

      Dir.glob(site.in_dest_dir("**", "*"), File::FNM_DOTMATCH) do |file|
        next if file =~ /\/\.{1,2}$/ || file =~ regex || dirs.include?(file)
        files << file
      end

      files
    end

    def new_files
      files = Set.new
      site.each_site_file { |item| files << item.destination(site.dest) }
      files
    end

    def new_dirs
      new_files.map { |file| parent_dirs(file) }.flatten.to_set
    end

    def parent_dirs(file)
      parent_dir = File.dirname(file)
      if parent_dir == site.dest
        []
      else
        [parent_dir] + parent_dirs(parent_dir)
      end
    end

    def replaced_files
      new_dirs.select { |dir| File.file?(dir) }.to_set
    end

    def keep_dirs
      site.keep_files.map { |file| parent_dirs(site.in_dest_dir(file)) }.flatten.to_set
    end

    def keep_file_regex
      Regexp.union(site.keep_files)
    end
  end
end
