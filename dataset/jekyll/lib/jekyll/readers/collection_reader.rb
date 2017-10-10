module Jekyll
  class CollectionReader
    attr_reader :site, :content
    def initialize(site)
      @site = site
      @content = {}
    end

    def read
      site.collections.each do |_, collection|
        collection.read unless collection.label.eql?('data')
      end
    end

  end
end
