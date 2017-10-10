require 'set'

module Sass
  module Util
    class SubsetMap
      def initialize
        @hash = {}
        @vals = []
      end

      def empty?
        @hash.empty?
      end

      def []=(set, value)
        raise ArgumentError.new("SubsetMap keys may not be empty.") if set.empty?

        index = @vals.size
        @vals << value
        set.each do |k|
          @hash[k] ||= []
          @hash[k] << [set, set.to_set, index]
        end
      end

      def get(set)
        res = set.map do |k|
          subsets = @hash[k]
          next unless subsets
          subsets.map do |subenum, subset, index|
            next unless subset.subset?(set)
            [index, subenum]
          end
        end
        res = Sass::Util.flatten(res, 1)
        res.compact!
        res.uniq!
        res.sort!
        res.map! {|i, s| [@vals[i], s]}
        res
      end

      def [](set)
        get(set).map {|v, _| v}
      end

      def each_value
        @vals.each {|v| yield v}
      end
    end
  end
end
