module Sass
  module Selector
    class SimpleSequence < AbstractSequence
      attr_accessor :members

      attr_accessor :sources

      attr_accessor :source_range

      attr_writer :subject

      def base
        @base ||= (members.first if members.first.is_a?(Element) || members.first.is_a?(Universal))
      end

      def pseudo_elements
        @pseudo_elements ||= members.select {|sel| sel.is_a?(Pseudo) && sel.type == :element}
      end

      def selector_pseudo_classes
        @selector_pseudo_classes ||= members.
          select {|sel| sel.is_a?(Pseudo) && sel.type == :class && sel.selector}.
          group_by {|sel| sel.normalized_name}
      end

      def rest
        @rest ||= Set.new(members - [base] - pseudo_elements)
      end

      def subject?
        @subject
      end

      def initialize(selectors, subject, source_range = nil)
        @members = selectors
        @subject = subject
        @sources = Set.new
        @source_range = source_range
      end

      def resolve_parent_refs(super_cseq)
        resolved_members = @members.map do |sel|
          next sel unless sel.is_a?(Pseudo) && sel.selector
          sel.with_selector(sel.selector.resolve_parent_refs(super_cseq, !:implicit_parent))
        end.flatten

        unless (parent = resolved_members.first).is_a?(Parent)
          return CommaSequence.new([Sequence.new([SimpleSequence.new(resolved_members, subject?)])])
        end

        return super_cseq if @members.size == 1 && parent.suffix.nil?

        CommaSequence.new(super_cseq.members.map do |super_seq|
          members = super_seq.members.dup
          newline = members.pop if members.last == "\n"
          unless members.last.is_a?(SimpleSequence)
            raise Sass::SyntaxError.new("Invalid parent selector for \"#{self}\": \"" +
              super_seq.to_s + '"')
          end

          parent_sub = members.last.members
          unless parent.suffix.nil?
            parent_sub = parent_sub.dup
            parent_sub[-1] = parent_sub.last.dup
            case parent_sub.last
            when Sass::Selector::Class, Sass::Selector::Id, Sass::Selector::Placeholder
              parent_sub[-1] = parent_sub.last.class.new(parent_sub.last.name + parent.suffix)
            when Sass::Selector::Element
              parent_sub[-1] = parent_sub.last.class.new(
                parent_sub.last.name + parent.suffix,
                parent_sub.last.namespace)
            when Sass::Selector::Pseudo
              if parent_sub.last.arg || parent_sub.last.selector
                raise Sass::SyntaxError.new("Invalid parent selector for \"#{self}\": \"" +
                  super_seq.to_s + '"')
              end
              parent_sub[-1] = Sass::Selector::Pseudo.new(
                parent_sub.last.type,
                parent_sub.last.name + parent.suffix,
                nil, nil)
            else
              raise Sass::SyntaxError.new("Invalid parent selector for \"#{self}\": \"" +
                super_seq.to_s + '"')
            end
          end

          Sequence.new(members[0...-1] +
            [SimpleSequence.new(parent_sub + resolved_members[1..-1], subject?)] +
            [newline].compact)
          end)
      end

      def do_extend(extends, parent_directives, replace, seen)
        seen_with_pseudo_selectors = seen.dup

        modified_original = false
        members = Sass::Util.enum_with_index(self.members).map do |sel, i|
          next sel unless sel.is_a?(Pseudo) && sel.selector
          next sel if seen.include?([sel])
          extended = sel.selector.do_extend(extends, parent_directives, replace, seen, !:original)
          next sel if extended == sel.selector
          extended.members.reject! {|seq| seq.has_placeholder?}

          if sel.normalized_name == 'not' &&
              (sel.selector.members.none? {|seq| seq.members.length > 1} &&
               extended.members.any? {|seq| seq.members.length == 1})
            extended.members.reject! {|seq| seq.members.length > 1}
          end

          modified_original = true
          result = sel.with_selector(extended)
          result.each {|new_sel| seen_with_pseudo_selectors << [new_sel]}
          result
        end.flatten

        groups = Sass::Util.group_by_to_a(extends[members.to_set]) {|ex| ex.extender}
        groups.map! do |seq, group|
          sels = group.map {|e| e.target}.flatten

          self_without_sel = Sass::Util.array_minus(members, sels)
          group.each {|e| e.result = :failed_to_unify unless e.result == :succeeded}
          unified = seq.members.last.unify(SimpleSequence.new(self_without_sel, subject?))
          next unless unified
          group.each {|e| e.result = :succeeded}
          group.each {|e| check_directives_match!(e, parent_directives)}
          new_seq = Sequence.new(seq.members[0...-1] + [unified])
          new_seq.add_sources!(sources + [seq])
          [sels, new_seq]
        end
        groups.compact!
        groups.map! do |sels, seq|
          next [] if seen.include?(sels)
          seq.do_extend(
            extends, parent_directives, !:replace, seen_with_pseudo_selectors + [sels], !:original)
        end
        groups.flatten!

        if modified_original || !replace || groups.empty?
          original = Sequence.new([SimpleSequence.new(members, @subject, source_range)])
          original.add_sources! sources
          groups.unshift original
        end
        groups.uniq!
        groups
      end

      def unify(other)
        sseq = members.inject(other.members) do |member, sel|
          return unless member
          sel.unify(member)
        end
        return unless sseq
        SimpleSequence.new(sseq, other.subject? || subject?)
      end

      def superselector?(their_sseq, parents = [])
        return false unless base.nil? || base.eql?(their_sseq.base)
        return false unless pseudo_elements.eql?(their_sseq.pseudo_elements)
        our_spcs = selector_pseudo_classes
        their_spcs = their_sseq.selector_pseudo_classes

        their_subselector_pseudos = %w[matches any nth-child nth-last-child].
          map {|name| their_spcs[name] || []}.flatten

        return false unless rest.all? do |our_sel|
          next true if our_sel.is_a?(Pseudo) && our_sel.selector
          next true if their_sseq.rest.include?(our_sel)
          their_subselector_pseudos.any? do |their_pseudo|
            their_pseudo.selector.members.all? do |their_seq|
              next false unless their_seq.members.length == 1
              their_sseq = their_seq.members.first
              next false unless their_sseq.is_a?(SimpleSequence)
              their_sseq.rest.include?(our_sel)
            end
          end
        end

        our_spcs.all? do |name, pseudos|
          pseudos.all? {|pseudo| pseudo.superselector?(their_sseq, parents)}
        end
      end

      def to_s
        res = @members.join
        res << '!' if subject?
        res
      end

      def inspect
        res = members.map {|m| m.inspect}.join
        res << '!' if subject?
        res
      end

      def with_more_sources(sources)
        sseq = dup
        sseq.members = members.dup
        sseq.sources = self.sources | sources
        sseq
      end

      private

      def check_directives_match!(extend, parent_directives)
        dirs1 = extend.directives.map {|d| d.resolved_value}
        dirs2 = parent_directives.map {|d| d.resolved_value}
        return if Sass::Util.subsequence?(dirs1, dirs2)
        line = extend.node.line
        filename = extend.node.filename

        raise Sass::SyntaxError.new(<<MESSAGE)
You may not @extend an outer selector from within #{extend.directives.last.name}.
You may only @extend selectors within the same directive.
From "@extend #{extend.target.join(', ')}" on line #{line}#{" of #{filename}" if filename}.
MESSAGE
      end

      def _hash
        [base, Sass::Util.set_hash(rest)].hash
      end

      def _eql?(other)
        other.base.eql?(base) && other.pseudo_elements == pseudo_elements &&
          Sass::Util.set_eql?(other.rest, rest) && other.subject? == subject?
      end
    end
  end
end
