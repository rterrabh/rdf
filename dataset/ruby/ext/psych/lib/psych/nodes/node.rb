require 'stringio'
require 'psych/class_loader'
require 'psych/scalar_scanner'

module Psych
  module Nodes
    class Node
      include Enumerable

      attr_reader :children

      attr_reader :tag

      def initialize
        @children = []
      end

      def each &block
        return enum_for :each unless block_given?
        Visitors::DepthFirst.new(block).accept self
      end

      def to_ruby
        Visitors::ToRuby.create.accept(self)
      end
      alias :transform :to_ruby

      def yaml io = nil, options = {}
        real_io = io || StringIO.new(''.encode('utf-8'))

        Visitors::Emitter.new(real_io, options).accept self
        return real_io.string unless io
        io
      end
      alias :to_yaml :yaml
    end
  end
end
