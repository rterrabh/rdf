module Jekyll
  class PageReader
    attr_reader :site, :dir, :unfiltered_content
    def initialize(site, dir)
      @site = site
      @dir = dir
      @unfiltered_content = Array.new
    end

    def read(files)
      files.map{ |page| @unfiltered_content << Page.new(@site, @site.source, @dir, page) }
      @unfiltered_content.select{ |page| site.publisher.publish?(page) }
    end
  end
end
