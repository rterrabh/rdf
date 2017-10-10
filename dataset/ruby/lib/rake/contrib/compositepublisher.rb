module Rake

  class CompositePublisher
    def initialize
      @publishers = []
    end

    def add(pub)
      @publishers << pub
    end

    def upload
      @publishers.each { |p| p.upload }
    end
  end

end

