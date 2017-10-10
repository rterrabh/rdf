require 'zlib'
require 'stringio'

module ActiveSupport
  module Gzip
    class Stream < StringIO
      def initialize(*)
        super
        set_encoding "BINARY"
      end
      def close; rewind; end
    end

    def self.decompress(source)
      Zlib::GzipReader.new(StringIO.new(source)).read
    end

    def self.compress(source, level=Zlib::DEFAULT_COMPRESSION, strategy=Zlib::DEFAULT_STRATEGY)
      output = Stream.new
      gz = Zlib::GzipWriter.new(output, level, strategy)
      gz.write(source)
      gz.close
      output.string
    end
  end
end
