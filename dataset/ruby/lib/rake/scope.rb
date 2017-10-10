module Rake
  class Scope < LinkedList # :nodoc: all

    def path
      map { |item| item.to_s }.reverse.join(":")
    end

    def path_with_task_name(task_name)
      "#{path}:#{task_name}"
    end

    def trim(n)
      result = self
      while n > 0 && ! result.empty?
        result = result.tail
        n -= 1
      end
      result
    end

    class EmptyScope < EmptyLinkedList
      @parent = Scope

      def path
        ""
      end

      def path_with_task_name(task_name)
        task_name
      end
    end

    EMPTY = EmptyScope.new
  end
end
