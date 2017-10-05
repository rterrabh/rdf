 require 'psych/json/ruby_events'

module Psych
  module Visitors
    class JSONTree < YAMLTree
      include Psych::JSON::RubyEvents

      def self.create options = {}
        emitter = Psych::JSON::TreeBuilder.new
        class_loader = ClassLoader.new
        ss           = ScalarScanner.new class_loader
        new(emitter, ss, options)
      end

      def accept target
        if target.respond_to?(:encode_with)
          dump_coder target
        else
          #nodyna <ID:send-6> <SD COMPLEX (change-prone variables)>
          send(@dispatch_cache[target.class], target)
        end
      end
    end
  end
end
