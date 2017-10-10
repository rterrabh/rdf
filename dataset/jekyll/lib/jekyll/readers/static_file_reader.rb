module Jekyll
  class StaticFileReader
    attr_reader :site, :dir, :unfiltered_content
    def initialize(site, dir)
      @site = site
      @dir = dir
      @unfiltered_content = Array.new
    end

    def read(files)
      files.map{ |file| @unfiltered_content << StaticFile.new(@site, @site.source, @dir, file)}
      @unfiltered_content
    end
  end
end
