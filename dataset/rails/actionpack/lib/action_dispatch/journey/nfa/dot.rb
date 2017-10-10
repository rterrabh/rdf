
module ActionDispatch
  module Journey # :nodoc:
    module NFA # :nodoc:
      module Dot # :nodoc:
        def to_dot
          edges = transitions.map { |from, sym, to|
            "  #{from} -> #{to} [label=\"#{sym || 'ε'}\"];"
          }


        <<-eodot
digraph nfa {
  rankdir=LR;
  node [shape = doublecircle];
  node [shape = circle];
}
        eodot
        end
      end
    end
  end
end
