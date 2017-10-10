module Jekyll
  class Layout
    include Convertible

    attr_reader :site

    attr_reader :name

    attr_reader :path

    attr_accessor :ext

    attr_accessor :data

    attr_accessor :content

    def initialize(site, base, name)
      @site = site
      @base = base
      @name = name
      @path = site.in_source_dir(base, name)

      self.data = {}

      process(name)
      read_yaml(base, name)
    end

    def process(name)
      self.ext = File.extname(name)
    end
  end
end
