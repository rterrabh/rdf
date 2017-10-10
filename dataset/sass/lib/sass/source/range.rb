module Sass::Source
  class Range
    attr_accessor :start_pos

    attr_accessor :end_pos

    attr_accessor :file

    attr_accessor :importer

    def initialize(start_pos, end_pos, file, importer = nil)
      @start_pos = start_pos
      @end_pos = end_pos
      @file = file
      @importer = importer
    end

    def inspect
      "(#{start_pos.inspect} to #{end_pos.inspect}#{" in #{@file}" if @file})"
    end
  end
end
