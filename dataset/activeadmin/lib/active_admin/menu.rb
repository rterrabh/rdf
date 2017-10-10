module ActiveAdmin

  class Menu

    def initialize
      super # MenuNode
      yield(self) if block_given?
    end

    module MenuNode
      def initialize
        @children = {}
      end

      def [](id)
        @children[normalize_id(id)]
      end
      def []=(id, child)
        @children[normalize_id(id)] = child
      end

      def add(options)
        item = if parent = options.delete(:parent)
          (self[parent] || add(label: parent)).add options
        else
          _add options.merge parent: self
        end

        yield(item) if block_given?

        item
      end

      def include?(item)
        @children.values.include? item
      end

      def current?(item)
        self == item || include?(item)
      end

      def items(context = nil)
        @children.values.select{ |i| i.display?(context) }.sort do |a,b|
          result = a.priority       <=> b.priority
          result = a.label(context) <=> b.label(context) if result == 0
          result
        end
      end

      attr_reader :children
      private
      attr_writer :children

      def _add(options)
        item = ActiveAdmin::MenuItem.new(options)
        #nodyna <send-83> <SD EASY (private methods)>
        item.send :children=, self[item.id].children if self[item.id]
        self[item.id] = item
      end

      def normalize_id(id)
        case id
        when String, Symbol, ActiveModel::Name
          id.to_s.downcase.tr ' ', '_'
        when ActiveAdmin::Resource::Name
          id.param_key
        else
          raise TypeError, "#{id.class} isn't supported as a Menu ID"
        end
      end
    end

    include MenuNode

  end
end
