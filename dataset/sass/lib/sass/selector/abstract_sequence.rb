module Sass
  module Selector
    class AbstractSequence
      attr_reader :line

      attr_reader :filename

      def line=(line)
        members.each {|m| m.line = line}
        @line = line
      end

      def filename=(filename)
        members.each {|m| m.filename = filename}
        @filename = filename
      end

      def hash
        @_hash ||= _hash
      end

      def eql?(other)
        other.class == self.class && other.hash == hash && _eql?(other)
      end
      alias_method :==, :eql?

      def has_placeholder?
        @has_placeholder ||= members.any? do |m|
          next m.has_placeholder? if m.is_a?(AbstractSequence)
          next m.selector && m.selector.has_placeholder? if m.is_a?(Pseudo)
          m.is_a?(Placeholder)
        end
      end

      def to_s
        Sass::Util.abstract(self)
      end

      def specificity
        _specificity(members)
      end

      protected

      def _specificity(arr)
        min = 0
        max = 0
        arr.each do |m|
          next if m.is_a?(String)
          spec = m.specificity
          if spec.is_a?(Range)
            min += spec.begin
            max += spec.end
          else
            min += spec
            max += spec
          end
        end
        min == max ? min : (min..max)
      end
    end
  end
end
