module Sass
  module Selector
    class CommaSequence < AbstractSequence
      attr_reader :members

      def initialize(seqs)
        @members = seqs
      end

      def resolve_parent_refs(super_cseq, implicit_parent = true)
        if super_cseq.nil?
          if contains_parent_ref?
            raise Sass::SyntaxError.new(
              "Base-level rules cannot contain the parent-selector-referencing character '&'.")
          end
          return self
        end

        CommaSequence.new(Sass::Util.flatten_vertically(@members.map do |seq|
          seq.resolve_parent_refs(super_cseq, implicit_parent).members
        end))
      end

      def contains_parent_ref?
        @members.any? {|sel| sel.contains_parent_ref?}
      end

      def do_extend(extends, parent_directives = [], replace = false, seen = Set.new,
          original = true)
        CommaSequence.new(members.map do |seq|
          seq.do_extend(extends, parent_directives, replace, seen, original)
        end.flatten)
      end

      def superselector?(cseq)
        cseq.members.all? {|seq1| members.any? {|seq2| seq2.superselector?(seq1)}}
      end

      def populate_extends(extends, extendee, extend_node = nil, parent_directives = [])
        extendee.members.each do |seq|
          if seq.members.size > 1
            raise Sass::SyntaxError.new("Can't extend #{seq}: can't extend nested selectors")
          end

          sseq = seq.members.first
          if !sseq.is_a?(Sass::Selector::SimpleSequence)
            raise Sass::SyntaxError.new("Can't extend #{seq}: invalid selector")
          elsif sseq.members.any? {|ss| ss.is_a?(Sass::Selector::Parent)}
            raise Sass::SyntaxError.new("Can't extend #{seq}: can't extend parent selectors")
          end

          sel = sseq.members
          members.each do |member|
            unless member.members.last.is_a?(Sass::Selector::SimpleSequence)
              raise Sass::SyntaxError.new("#{member} can't extend: invalid selector")
            end

            extends[sel] = Sass::Tree::Visitors::Cssize::Extend.new(
              member, sel, extend_node, parent_directives, :not_found)
          end
        end
      end

      def unify(other)
        results = members.map {|seq1| other.members.map {|seq2| seq1.unify(seq2)}}.flatten.compact
        results.empty? ? nil : CommaSequence.new(results.map {|cseq| cseq.members}.flatten)
      end

      def to_sass_script
        Sass::Script::Value::List.new(members.map do |seq|
          Sass::Script::Value::List.new(seq.members.map do |component|
            next if component == "\n"
            Sass::Script::Value::String.new(component.to_s)
          end.compact, :space)
        end, :comma)
      end

      def inspect
        members.map {|m| m.inspect}.join(", ")
      end

      def to_s
        @members.join(", ").gsub(", \n", ",\n")
      end

      private

      def _hash
        members.hash
      end

      def _eql?(other)
        other.class == self.class && other.members.eql?(members)
      end
    end
  end
end
