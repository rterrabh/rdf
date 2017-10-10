module REXML
  class SyncEnumerator
    include Enumerable

    def initialize(*enums)
      @gens = enums
      @length = @gens.collect {|x| x.size }.max
    end

    def size
      @gens.size
    end

    def length
      @gens.length
    end

    def each
      @length.times {|i|
        yield @gens.collect {|x| x[i]}
      }
      self
    end
  end
end
