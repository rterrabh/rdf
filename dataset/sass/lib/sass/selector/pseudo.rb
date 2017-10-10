module Sass
  module Selector
    class Pseudo < Simple
      ACTUALLY_ELEMENTS = %w[after before first-line first-letter].to_set

      attr_reader :syntactic_type

      attr_reader :name

      attr_reader :arg

      attr_reader :selector

      def initialize(syntactic_type, name, arg, selector)
        @syntactic_type = syntactic_type
        @name = name
        @arg = arg
        @selector = selector
      end

      def with_selector(new_selector)
        result = Pseudo.new(syntactic_type, name, arg,
          CommaSequence.new(new_selector.members.map do |seq|
            next seq unless seq.members.length == 1
            sseq = seq.members.first
            next seq unless sseq.is_a?(SimpleSequence) && sseq.members.length == 1
            sel = sseq.members.first
            next seq unless sel.is_a?(Pseudo) && sel.selector

            case normalized_name
            when 'not'
              next [] unless sel.normalized_name == 'matches'
              sel.selector.members
            when 'matches', 'any', 'current', 'nth-child', 'nth-last-child'
              next [] unless sel.name == name && sel.arg == arg
              sel.selector.members
            when 'has', 'host', 'host-context'
              sel
            else
              []
            end
          end.flatten))

        return [result] unless normalized_name == 'not'
        return [result] if selector.members.length > 1
        result.selector.members.map do |seq|
          Pseudo.new(syntactic_type, name, arg, CommaSequence.new([seq]))
        end
      end

      def type
        ACTUALLY_ELEMENTS.include?(normalized_name) ? :element : syntactic_type
      end

      def normalized_name
        @normalized_name ||= name.gsub(/^-[a-zA-Z0-9]+-/, '')
      end

      def to_s
        res = (syntactic_type == :class ? ":" : "::") + @name
        if @arg || @selector
          res << "("
          res << @arg.strip if @arg
          res << " " if @arg && @selector
          res << @selector.to_s if @selector
          res << ")"
        end
        res
      end

      def unify(sels)
        return if type == :element && sels.any? do |sel|
          sel.is_a?(Pseudo) && sel.type == :element &&
            (sel.name != name || sel.arg != arg || sel.selector != selector)
        end
        super
      end

      def superselector?(their_sseq, parents = [])
        case normalized_name
        when 'matches', 'any'
          (their_sseq.selector_pseudo_classes[normalized_name] || []).any? do |their_sel|
            next false unless their_sel.is_a?(Pseudo)
            next false unless their_sel.name == name
            selector.superselector?(their_sel.selector)
          end || selector.members.any? do |our_seq|
            their_seq = Sequence.new(parents + [their_sseq])
            our_seq.superselector?(their_seq)
          end
        when 'has', 'host', 'host-context'
          (their_sseq.selector_pseudo_classes[normalized_name] || []).any? do |their_sel|
            next false unless their_sel.is_a?(Pseudo)
            next false unless their_sel.name == name
            selector.superselector?(their_sel.selector)
          end
        when 'not'
          selector.members.all? do |our_seq|
            their_sseq.members.any? do |their_sel|
              if their_sel.is_a?(Element) || their_sel.is_a?(Id)
                our_sseq = our_seq.members.last
                next false unless our_sseq.is_a?(SimpleSequence)
                our_sseq.members.any? do |our_sel|
                  our_sel.class == their_sel.class && our_sel != their_sel
                end
              else
                next false unless their_sel.is_a?(Pseudo)
                next false unless their_sel.name == name
                their_sel.selector.superselector?(CommaSequence.new([our_seq]))
              end
            end
          end
        when 'current'
          (their_sseq.selector_pseudo_classes['current'] || []).any? do |their_current|
            next false if their_current.name != name
            selector == their_current.selector
          end
        when 'nth-child', 'nth-last-child'
          their_sseq.members.any? do |their_sel|
            next false unless their_sel.is_a?(Pseudo)
            next false unless their_sel.name == name
            next false unless their_sel.arg == arg
            selector.superselector?(their_sel.selector)
          end
        else
          throw "[BUG] Unknown selector pseudo class #{name}"
        end
      end

      def specificity
        return 1 if type == :element
        return SPECIFICITY_BASE unless selector
        @specificity ||=
          if normalized_name == 'not'
            min = 0
            max = 0
            selector.members.each do |seq|
              spec = seq.specificity
              if spec.is_a?(Range)
                min = Sass::Util.max(spec.begin, min)
                max = Sass::Util.max(spec.end, max)
              else
                min = Sass::Util.max(spec, min)
                max = Sass::Util.max(spec, max)
              end
            end
            min == max ? max : (min..max)
          else
            min = 0
            max = 0
            selector.members.each do |seq|
              spec = seq.specificity
              if spec.is_a?(Range)
                min = Sass::Util.min(spec.begin, min)
                max = Sass::Util.max(spec.end, max)
              else
                min = Sass::Util.min(spec, min)
                max = Sass::Util.max(spec, max)
              end
            end
            min == max ? max : (min..max)
          end
      end
    end
  end
end
