require 'csv'

module Jekyll
  class Reader
    attr_reader :site

    def initialize(site)
      @site = site
    end

    def read
      @site.layouts = LayoutReader.new(site).read
      read_directories
      sort_files!
      @site.data = DataReader.new(site).read(site.config['data_source'])
      CollectionReader.new(site).read
    end

    def sort_files!
      site.posts.sort!
      site.pages.sort_by!(&:name)
      site.static_files.sort_by!(&:relative_path)
    end

    def read_directories(dir = '')
      base = site.in_source_dir(dir)

      dot = Dir.chdir(base) { filter_entries(Dir.entries('.'), base) }
      dot_dirs = dot.select{ |file| File.directory?(@site.in_source_dir(base,file)) }
      dot_files = (dot - dot_dirs)
      dot_pages = dot_files.select{ |file| Utils.has_yaml_header?(@site.in_source_dir(base,file)) }
      dot_static_files = dot_files - dot_pages

      retrieve_posts(dir)
      retrieve_dirs(base, dir, dot_dirs)
      retrieve_pages(dir, dot_pages)
      retrieve_static_files(dir, dot_static_files)
    end

    def retrieve_posts(dir)
      site.posts.concat(PostReader.new(site).read(dir))
      site.posts.concat(DraftReader.new(site).read(dir)) if site.show_drafts
    end

    def retrieve_dirs(base, dir, dot_dirs)
      dot_dirs.map { |file|
        dir_path = site.in_source_dir(dir,file)
        rel_path = File.join(dir, file)
        @site.reader.read_directories(rel_path) unless @site.dest.sub(/\/$/, '') == dir_path
      }
    end

    def retrieve_pages(dir, dot_pages)
      site.pages.concat(PageReader.new(site, dir).read(dot_pages))
    end

    def retrieve_static_files(dir, dot_static_files)
      site.static_files.concat(StaticFileReader.new(site, dir).read(dot_static_files))
    end

    def filter_entries(entries, base_directory = nil)
      EntryFilter.new(site, base_directory).filter(entries)
    end

    def get_entries(dir, subfolder)
      base = site.in_source_dir(dir, subfolder)
      return [] unless File.exist?(base)
      entries = Dir.chdir(base) { filter_entries(Dir['**/*'], base) }
      entries.delete_if { |e| File.directory?(site.in_source_dir(base, e)) }
    end
  end
end
