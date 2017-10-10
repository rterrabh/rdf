module Resque
  module Failure
    class Multiple < Base

      class << self
        attr_accessor :classes
      end

      def self.configure
        yield self
        Resque::Failure.backend = self
      end

      def initialize(*args)
        super
        @backends = self.class.classes.map {|klass| klass.new(*args)}
      end

      def save
        @backends.each(&:save)
      end

      def self.count(*args)
        classes.first.count(*args)
      end

      def self.all(*args)
        classes.first.all(*args)
      end

      def self.each(*args, &block)
        classes.first.each(*args, &block)
      end

      def self.url
        classes.first.url
      end

      def self.clear(*args)
        classes.first.clear(*args)
      end

      def self.requeue(*args)
        classes.first.requeue(*args)
      end

      def self.remove(index)
        classes.each { |klass| klass.remove(index) }
      end
    end
  end
end
