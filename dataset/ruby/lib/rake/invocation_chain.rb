module Rake

  class InvocationChain < LinkedList

    def member?(invocation)
      head == invocation || tail.member?(invocation)
    end

    def append(invocation)
      if member?(invocation)
        fail RuntimeError, "Circular dependency detected: #{to_s} => #{invocation}"
      end
      conj(invocation)
    end

    def to_s
      "#{prefix}#{head}"
    end

    def self.append(invocation, chain)
      chain.append(invocation)
    end

    private

    def prefix
      "#{tail} => "
    end

    class EmptyInvocationChain < LinkedList::EmptyLinkedList
      @parent = InvocationChain

      def member?(obj)
        false
      end

      def append(invocation)
        conj(invocation)
      end

      def to_s
        "TOP"
      end
    end

    EMPTY = EmptyInvocationChain.new
  end
end
