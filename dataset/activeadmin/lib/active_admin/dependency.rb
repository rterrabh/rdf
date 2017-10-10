module ActiveAdmin
  module Dependency
    DEVISE = '~> 3.2'

    def self.method_missing(name, *args)
      if name[-1] == '?'
        Matcher.new(name[0..-2]).match? args
      elsif name[-1] == '!'
        Matcher.new(name[0..-2]).match! args
      else
        Matcher.new name.to_s
      end
    end

    def self.[](name)
      Matcher.new name.to_s
    end

    class Matcher
      def initialize(name)
        @name, @spec = name, Gem.loaded_specs[name]
      end

      def match?(*reqs)
        !!@spec && Gem::Requirement.create(reqs).satisfied_by?(@spec.version)
      end

      def match!(*reqs)
        unless @spec
          raise DependencyError, "To use #{@name} you need to specify it in your Gemfile."
        end

        unless match? reqs
          raise DependencyError, "You provided #{@spec.name} #{@spec.version} but we need: #{reqs.join ', '}."
        end
      end

      include Comparable

      def <=>(other)
        if @spec
          @spec.version <=> Gem::Version.create(other)
        else
          raise DependencyError, "To use #{@name} you need to specify it in your Gemfile."
        end
      end

      def inspect
        info = @spec ? "#{@spec.name} #{@spec.version}" : '(missing)'
        "<ActiveAdmin::Dependency::Matcher for #{info}>"
      end
    end
  end
end
