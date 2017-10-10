module Jekyll
  class DraftReader
    attr_reader :site, :unfiltered_content
    def initialize(site)
      @site = site
      @unfiltered_content = Array.new
    end

    def read(dir)
      @unfiltered_content = read_content(dir, '_drafts')
      @unfiltered_content.select{ |draft| site.publisher.publish?(draft) }
    end

    def read_content(dir, magic_dir)
      @site.reader.get_entries(dir, magic_dir).map do |entry|
        Draft.new(site, site.source, dir, entry) if Draft.valid?(entry)
      end.reject do |entry|
        entry.nil?
      end
    end
  end
end
