module Capybara
  module Node

    class Element < Base

      def initialize(session, base, parent, query)
        super(session, base)
        @parent = parent
        @query = query
      end

      def allow_reload!
        @allow_reload = true
      end

      def native
        synchronize { base.native }
      end

      def text(type=nil)
        type ||= :all unless Capybara.ignore_hidden_elements or Capybara.visible_text_only
        synchronize do
          if type == :all
            base.all_text
          else
            base.visible_text
          end
        end
      end

      def [](attribute)
        synchronize { base[attribute] }
      end

      def value
        synchronize { base.value }
      end

      def set(value, options={})
        options ||= {}

        driver_supports_options = (base.method(:set).arity != 1)

        unless options.empty? || driver_supports_options
          warn "Options passed to Capybara::Node#set but the driver doesn't support them"
        end

        synchronize do
          if driver_supports_options
            base.set(value, options)
          else
            base.set(value)
          end
        end
      end

      def select_option
        warn "Attempt to select disabled option: #{value || text}" if disabled?
        synchronize { base.select_option }
      end

      def unselect_option
        synchronize { base.unselect_option }
      end

      def click
        synchronize { base.click }
      end

      def right_click
        synchronize { base.right_click }
      end

      def double_click
        synchronize { base.double_click }
      end

      def send_keys(*args)
        synchronize { base.send_keys(*args) }
      end

      def hover
        synchronize { base.hover }
      end

      def tag_name
        synchronize { base.tag_name }
      end

      def visible?
        synchronize { base.visible? }
      end

      def checked?
        synchronize { base.checked? }
      end

      def selected?
        synchronize { base.selected? }
      end

      def disabled?
        synchronize { base.disabled? }
      end

      def path
        synchronize { base.path }
      end

      def trigger(event)
        synchronize { base.trigger(event) }
      end

      def drag_to(node)
        synchronize { base.drag_to(node.base) }
      end

      def reload
        if @allow_reload
          begin
            reloaded = parent.reload.first(@query.name, @query.locator, @query.options)
            @base = reloaded.base if reloaded
          rescue => e
            raise e unless catch_error?(e)
          end
        end
        self
      end

      def inspect
        %(#<Capybara::Node::Element tag="#{tag_name}" path="#{path}">)
      rescue NotSupportedByDriverError
        %(#<Capybara::Node::Element tag="#{tag_name}">)
      end
    end
  end
end
