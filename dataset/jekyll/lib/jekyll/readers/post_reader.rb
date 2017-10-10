module Jekyll
  class PostReader
    attr_reader :site, :unfiltered_content
    def initialize(site)
      @site = site
      @unfiltered_content = Array.new
    end

    def read(dir)
      @unfiltered_content = read_content(dir, '_posts')
      @unfiltered_content.select{ |post| site.publisher.publish?(post) }
    end

    def read_content(dir, magic_dir)
      @site.reader.get_entries(dir, magic_dir).map do |entry|
        Post.new(site, site.source, dir, entry) if Post.valid?(entry)
      end.reject do |entry|
        entry.nil?
      end
    end
  end
end
