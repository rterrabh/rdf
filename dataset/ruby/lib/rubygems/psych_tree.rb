module Gem
  if defined? ::Psych::Visitors
    class NoAliasYAMLTree < Psych::Visitors::YAMLTree
      def self.create
        new({})
      end unless respond_to? :create

      def visit_String(str)
        return super unless str == '=' # or whatever you want

        quote = Psych::Nodes::Scalar::SINGLE_QUOTED
        @emitter.scalar str, nil, nil, false, true, quote
      end

      def register(target, obj)
      end

      def format_time time
        if time.utc?
          time.strftime("%Y-%m-%d %H:%M:%S.%9N Z")
        else
          time.strftime("%Y-%m-%d %H:%M:%S.%9N %:z")
        end
      end

      private :format_time
    end
  end
end
