module Sass
  module Selector
    class Sequence < AbstractSequence
      def line=(line)
        members.each {|m| m.line = line if m.is_a?(SimpleSequence)}
        @line = line
      end

      def filename=(filename)
        members.each {|m| m.filename = filename if m.is_a?(SimpleSequence)}
        filename
      end

      attr_reader :members

      def initialize(seqs_and_ops)
        @members = seqs_and_ops
      end

      def resolve_parent_refs(super_cseq, implicit_parent)
        members = @members.dup
        nl = (members.first == "\n" && members.shift)
        contains_parent_ref = contains_parent_ref?
        return CommaSequence.new([self]) if !implicit_parent && !contains_parent_ref

        unless contains_parent_ref
          old_members, members = members, []
          members << nl if nl
          members << SimpleSequence.new([Parent.new], false)
          members += old_members
        end

        CommaSequence.new(Sass::Util.paths(members.map do |sseq_or_op|
          next [sseq_or_op] unless sseq_or_op.is_a?(SimpleSequence)
          sseq_or_op.resolve_parent_refs(super_cseq).members
        end).map do |path|
          Sequence.new(path.map do |seq_or_op|
            next seq_or_op unless seq_or_op.is_a?(Sequence)
            seq_or_op.members
          end.flatten)
        end)
      end

      def contains_parent_ref?
        members.any? do |sseq_or_op|
          next false unless sseq_or_op.is_a?(SimpleSequence)
          next true if sseq_or_op.members.first.is_a?(Parent)
          sseq_or_op.members.any? do |sel|
            sel.is_a?(Pseudo) && sel.selector && sel.selector.contains_parent_ref?
          end
        end
      end

      def do_extend(extends, parent_directives, replace, seen, original)
        extended_not_expanded = members.map do |sseq_or_op|
          next [[sseq_or_op]] unless sseq_or_op.is_a?(SimpleSequence)
          extended = sseq_or_op.do_extend(extends, parent_directives, replace, seen)

          extended.first.add_sources!([self]) if original && !has_placeholder?

          extended.map {|seq| seq.members}
        end
        weaves = Sass::Util.paths(extended_not_expanded).map {|path| weave(path)}
        trim(weaves).map {|p| Sequence.new(p)}
      end

      def unify(other)
        base = members.last
        other_base = other.members.last
        return unless base.is_a?(SimpleSequence) && other_base.is_a?(SimpleSequence)
        return unless (unified = other_base.unify(base))

        woven = weave([members[0...-1], other.members[0...-1] + [unified]])
        CommaSequence.new(woven.map {|w| Sequence.new(w)})
      end

      def superselector?(seq)
        _superselector?(members, seq.members)
      end

      def to_s
        @members.join(" ").gsub(/ ?\n ?/, "\n")
      end

      def inspect
        members.map {|m| m.inspect}.join(" ")
      end

      def add_sources!(sources)
        members.map! {|m| m.is_a?(SimpleSequence) ? m.with_more_sources(sources) : m}
      end

      def subjectless
        pre_subject = []
        has = []
        subject = nil
        members.each do |sseq_or_op|
          if subject
            has << sseq_or_op
          elsif sseq_or_op.is_a?(String) || !sseq_or_op.subject?
            pre_subject << sseq_or_op
          else
            subject = sseq_or_op.dup
            subject.members = sseq_or_op.members.dup
            subject.subject = false
            has = []
          end
        end

        return self unless subject

        unless has.empty?
          subject.members << Pseudo.new(:class, 'has', nil, CommaSequence.new([Sequence.new(has)]))
        end
        Sequence.new(pre_subject + [subject])
      end

      private

      def weave(path)
        prefixes = [[]]

        path.each do |current|
          next if current.empty?
          current = current.dup
          last_current = [current.pop]
          prefixes = Sass::Util.flatten(prefixes.map do |prefix|
            sub = subweave(prefix, current)
            next [] unless sub
            sub.map {|seqs| seqs + last_current}
          end, 1)
        end
        prefixes
      end

      def subweave(seq1, seq2)
        return [seq2] if seq1.empty?
        return [seq1] if seq2.empty?

        seq1, seq2 = seq1.dup, seq2.dup
        return unless (init = merge_initial_ops(seq1, seq2))
        return unless (fin = merge_final_ops(seq1, seq2))

        root1 = has_root?(seq1.first) && seq1.shift
        root2 = has_root?(seq2.first) && seq2.shift
        if root1 && root2
          return unless (root = root1.unify(root2))
          seq1.unshift root
          seq2.unshift root
        elsif root1
          seq2.unshift root1
        elsif root2
          seq1.unshift root2
        end

        seq1 = group_selectors(seq1)
        seq2 = group_selectors(seq2)
        lcs = Sass::Util.lcs(seq2, seq1) do |s1, s2|
          next s1 if s1 == s2
          next unless s1.first.is_a?(SimpleSequence) && s2.first.is_a?(SimpleSequence)
          next s2 if parent_superselector?(s1, s2)
          next s1 if parent_superselector?(s2, s1)
        end

        diff = [[init]]

        until lcs.empty?
          diff << chunks(seq1, seq2) {|s| parent_superselector?(s.first, lcs.first)} << [lcs.shift]
          seq1.shift
          seq2.shift
        end
        diff << chunks(seq1, seq2) {|s| s.empty?}
        diff += fin.map {|sel| sel.is_a?(Array) ? sel : [sel]}
        diff.reject! {|c| c.empty?}

        Sass::Util.paths(diff).map {|p| p.flatten}.reject {|p| path_has_two_subjects?(p)}
      end

      def merge_initial_ops(seq1, seq2)
        ops1, ops2 = [], []
        ops1 << seq1.shift while seq1.first.is_a?(String)
        ops2 << seq2.shift while seq2.first.is_a?(String)

        newline = false
        newline ||= !!ops1.shift if ops1.first == "\n"
        newline ||= !!ops2.shift if ops2.first == "\n"

        lcs = Sass::Util.lcs(ops1, ops2)
        return unless lcs == ops1 || lcs == ops2
        (newline ? ["\n"] : []) + (ops1.size > ops2.size ? ops1 : ops2)
      end

      def merge_final_ops(seq1, seq2, res = [])
        ops1, ops2 = [], []
        ops1 << seq1.pop while seq1.last.is_a?(String)
        ops2 << seq2.pop while seq2.last.is_a?(String)

        ops1.reject! {|o| o == "\n"}
        ops2.reject! {|o| o == "\n"}

        return res if ops1.empty? && ops2.empty?
        if ops1.size > 1 || ops2.size > 1
          lcs = Sass::Util.lcs(ops1, ops2)
          return unless lcs == ops1 || lcs == ops2
          res.unshift(*(ops1.size > ops2.size ? ops1 : ops2).reverse)
          return res
        end

        op1, op2 = ops1.first, ops2.first
        if op1 && op2
          sel1 = seq1.pop
          sel2 = seq2.pop
          if op1 == '~' && op2 == '~'
            if sel1.superselector?(sel2)
              res.unshift sel2, '~'
            elsif sel2.superselector?(sel1)
              res.unshift sel1, '~'
            else
              merged = sel1.unify(sel2)
              res.unshift [
                [sel1, '~', sel2, '~'],
                [sel2, '~', sel1, '~'],
                ([merged, '~'] if merged)
              ].compact
            end
          elsif (op1 == '~' && op2 == '+') || (op1 == '+' && op2 == '~')
            if op1 == '~'
              tilde_sel, plus_sel = sel1, sel2
            else
              tilde_sel, plus_sel = sel2, sel1
            end

            if tilde_sel.superselector?(plus_sel)
              res.unshift plus_sel, '+'
            else
              merged = plus_sel.unify(tilde_sel)
              res.unshift [
                [tilde_sel, '~', plus_sel, '+'],
                ([merged, '+'] if merged)
              ].compact
            end
          elsif op1 == '>' && %w[~ +].include?(op2)
            res.unshift sel2, op2
            seq1.push sel1, op1
          elsif op2 == '>' && %w[~ +].include?(op1)
            res.unshift sel1, op1
            seq2.push sel2, op2
          elsif op1 == op2
            merged = sel1.unify(sel2)
            return unless merged
            res.unshift merged, op1
          else
            return
          end
          return merge_final_ops(seq1, seq2, res)
        elsif op1
          seq2.pop if op1 == '>' && seq2.last && seq2.last.superselector?(seq1.last)
          res.unshift seq1.pop, op1
          return merge_final_ops(seq1, seq2, res)
        else # op2
          seq1.pop if op2 == '>' && seq1.last && seq1.last.superselector?(seq2.last)
          res.unshift seq2.pop, op2
          return merge_final_ops(seq1, seq2, res)
        end
      end

      def chunks(seq1, seq2)
        chunk1 = []
        chunk1 << seq1.shift until yield seq1
        chunk2 = []
        chunk2 << seq2.shift until yield seq2
        return [] if chunk1.empty? && chunk2.empty?
        return [chunk2] if chunk1.empty?
        return [chunk1] if chunk2.empty?
        [chunk1 + chunk2, chunk2 + chunk1]
      end

      def group_selectors(seq)
        newseq = []
        tail = seq.dup
        until tail.empty?
          head = []
          begin
            head << tail.shift
          end while !tail.empty? && head.last.is_a?(String) || tail.first.is_a?(String)
          newseq << head
        end
        newseq
      end

      def _superselector?(seq1, seq2)
        seq1 = seq1.reject {|e| e == "\n"}
        seq2 = seq2.reject {|e| e == "\n"}
        return if seq1.last.is_a?(String) || seq2.last.is_a?(String) ||
          seq1.first.is_a?(String) || seq2.first.is_a?(String)
        return if seq1.size > seq2.size
        return seq1.first.superselector?(seq2.last, seq2[0...-1]) if seq1.size == 1

        _, si = Sass::Util.enum_with_index(seq2).find do |e, i|
          return if i == seq2.size - 1
          next if e.is_a?(String)
          seq1.first.superselector?(e, seq2[0...i])
        end
        return unless si

        if seq1[1].is_a?(String)
          return unless seq2[si + 1].is_a?(String)

          return unless seq1[1] == "~" ? seq2[si + 1] != ">" : seq1[1] == seq2[si + 1]

          return if seq1.length == 3 && seq2.length > 3

          return _superselector?(seq1[2..-1], seq2[si + 2..-1])
        elsif seq2[si + 1].is_a?(String)
          return unless seq2[si + 1] == ">"
          return _superselector?(seq1[1..-1], seq2[si + 2..-1])
        else
          return _superselector?(seq1[1..-1], seq2[si + 1..-1])
        end
      end

      def parent_superselector?(seq1, seq2)
        base = Sass::Selector::SimpleSequence.new([Sass::Selector::Placeholder.new('<temp>')],
                                                  false)
        _superselector?(seq1 + [base], seq2 + [base])
      end

      def trim(seqses)
        return Sass::Util.flatten(seqses, 1) if seqses.size > 100

        result = seqses.dup

        seqses.each_with_index do |seqs1, i|
          result[i] = seqs1.reject do |seq1|
            max_spec = _sources(seq1).map do |seq|
              spec = seq.specificity
              spec.is_a?(Range) ? spec.max : spec
            end.max || 0

            result.any? do |seqs2|
              next if seqs1.equal?(seqs2)
              seqs2.any? do |seq2|
                spec2 = _specificity(seq2)
                spec2 = spec2.begin if spec2.is_a?(Range)
                spec2 >= max_spec && _superselector?(seq2, seq1)
              end
            end
          end
        end
        Sass::Util.flatten(result, 1)
      end

      def _hash
        members.reject {|m| m == "\n"}.hash
      end

      def _eql?(other)
        other.members.reject {|m| m == "\n"}.eql?(members.reject {|m| m == "\n"})
      end

      private

      def path_has_two_subjects?(path)
        subject = false
        path.each do |sseq_or_op|
          next unless sseq_or_op.is_a?(SimpleSequence)
          next unless sseq_or_op.subject?
          return true if subject
          subject = true
        end
        false
      end

      def _sources(seq)
        s = Set.new
        seq.map {|sseq_or_op| s.merge sseq_or_op.sources if sseq_or_op.is_a?(SimpleSequence)}
        s
      end

      def extended_not_expanded_to_s(extended_not_expanded)
        extended_not_expanded.map do |choices|
          choices = choices.map do |sel|
            next sel.first.to_s if sel.size == 1
            "#{sel.join ' '}"
          end
          next choices.first if choices.size == 1 && !choices.include?(' ')
          "(#{choices.join ', '})"
        end.join ' '
      end

      def has_root?(sseq)
        sseq.is_a?(SimpleSequence) &&
          sseq.members.any? {|sel| sel.is_a?(Pseudo) && sel.normalized_name == "root"}
      end
    end
  end
end
