module Psych
  module Visitors
    class Visitor
      def accept target
        visit target
      end

      private

      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{klass.name.gsub('::', '_')}"
      end

      def visit target
        #nodyna <ID:send-5> <send VERY HIGH ex3>
        send DISPATCH[target.class], target
      end
    end
  end
end
