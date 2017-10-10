module Sass
  module Selector
    class Simple
      attr_accessor :line

      attr_accessor :filename

      def inspect
        to_s
      end

      def to_s
        Sass::Util.abstract(self)
      end

      def hash
        @_hash ||= equality_key.hash
      end

      def eql?(other)
        other.class == self.class && other.hash == hash && other.equality_key == equality_key
      end
      alias_method :==, :eql?

      def unify(sels)
        return sels if sels.any? {|sel2| eql?(sel2)}
        sels_with_ix = Sass::Util.enum_with_index(sels)
        if !is_a?(Pseudo) || (sels.last.is_a?(Pseudo) && sels.last.type == :element)
          _, i = sels_with_ix.find {|sel, _| sel.is_a?(Pseudo)}
        end
        return sels + [self] unless i
        sels[0...i] + [self] + sels[i..-1]
      end

      protected

      def equality_key
        @equality_key ||= to_s
      end

      def unify_namespaces(ns1, ns2)
        return nil, false unless ns1 == ns2 || ns1.nil? || ns1 == '*' || ns2.nil? || ns2 == '*'
        return ns2, true if ns1 == '*'
        return ns1, true if ns2 == '*'
        [ns1 || ns2, true]
      end
    end
  end
end
