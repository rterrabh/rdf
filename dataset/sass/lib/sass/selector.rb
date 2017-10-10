require 'sass/selector/simple'
require 'sass/selector/abstract_sequence'
require 'sass/selector/comma_sequence'
require 'sass/selector/pseudo'
require 'sass/selector/sequence'
require 'sass/selector/simple_sequence'

module Sass
  module Selector
    SPECIFICITY_BASE = 1_000

    class Parent < Simple
      attr_reader :suffix

      def initialize(suffix = nil)
        @suffix = suffix
      end

      def to_s
        "&" + (@suffix || '')
      end

      def unify(sels)
        raise Sass::SyntaxError.new("[BUG] Cannot unify parent selectors.")
      end
    end

    class Class < Simple
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_s
        "." + @name
      end

      def specificity
        SPECIFICITY_BASE
      end
    end

    class Id < Simple
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_s
        "#" + @name
      end

      def unify(sels)
        return if sels.any? {|sel2| sel2.is_a?(Id) && name != sel2.name}
        super
      end

      def specificity
        SPECIFICITY_BASE**2
      end
    end

    class Placeholder < Simple
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def to_s
        "%" + @name
      end

      def specificity
        SPECIFICITY_BASE
      end
    end

    class Universal < Simple
      attr_reader :namespace

      def initialize(namespace)
        @namespace = namespace
      end

      def to_s
        @namespace ? "#{@namespace}|*" : "*"
      end

      def unify(sels)
        name =
          case sels.first
          when Universal; :universal
          when Element; sels.first.name
          else
            return [self] + sels unless namespace.nil? || namespace == '*'
            return sels unless sels.empty?
            return [self]
          end

        ns, accept = unify_namespaces(namespace, sels.first.namespace)
        return unless accept
        [name == :universal ? Universal.new(ns) : Element.new(name, ns)] + sels[1..-1]
      end

      def specificity
        0
      end
    end

    class Element < Simple
      attr_reader :name

      attr_reader :namespace

      def initialize(name, namespace)
        @name = name
        @namespace = namespace
      end

      def to_s
        @namespace ? "#{@namespace}|#{@name}" : @name
      end

      def unify(sels)
        case sels.first
        when Universal;
        when Element; return unless name == sels.first.name
        else return [self] + sels
        end

        ns, accept = unify_namespaces(namespace, sels.first.namespace)
        return unless accept
        [Element.new(name, ns)] + sels[1..-1]
      end

      def specificity
        1
      end
    end

    class Attribute < Simple
      attr_reader :name

      attr_reader :namespace

      attr_reader :operator

      attr_reader :value

      attr_reader :flags

      def initialize(name, namespace, operator, value, flags)
        @name = name
        @namespace = namespace
        @operator = operator
        @value = value
        @flags = flags
      end

      def to_s
        res = "["
        res << @namespace << "|" if @namespace
        res << @name
        res << @operator << @value if @value
        res << " " << @flags if @flags
        res << "]"
      end

      def specificity
        SPECIFICITY_BASE
      end
    end
  end
end
