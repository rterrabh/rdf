module AbstractController
  module Callbacks
    extend ActiveSupport::Concern

    include ActiveSupport::Callbacks

    included do
      define_callbacks :process_action,
                       terminator: ->(controller,_) { controller.response_body },
                       skip_after_callbacks_if_terminated: true
    end

    def process_action(*args)
      run_callbacks(:process_action) do
        super
      end
    end

    module ClassMethods
      def _normalize_callback_options(options)
        _normalize_callback_option(options, :only, :if)
        _normalize_callback_option(options, :except, :unless)
      end

      def _normalize_callback_option(options, from, to) # :nodoc:
        if from = options[from]
          from = Array(from).map {|o| "action_name == '#{o}'"}.join(" || ")
          options[to] = Array(options[to]).unshift(from)
        end
      end

      def skip_action_callback(*names)
        skip_before_action(*names)
        skip_after_action(*names)
        skip_around_action(*names)
      end
      alias_method :skip_filter, :skip_action_callback

      def _insert_callbacks(callbacks, block = nil)
        options = callbacks.extract_options!
        _normalize_callback_options(options)
        callbacks.push(block) if block
        callbacks.each do |callback|
          yield callback, options
        end
      end













      [:before, :after, :around].each do |callback|
        #nodyna <define_method-1309> <DM MODERATE (array)>
        define_method "#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options)
          end
        end
        alias_method :"#{callback}_filter", :"#{callback}_action"

        #nodyna <define_method-1310> <DM MODERATE (array)>
        define_method "prepend_#{callback}_action" do |*names, &blk|
          _insert_callbacks(names, blk) do |name, options|
            set_callback(:process_action, callback, name, options.merge(:prepend => true))
          end
        end
        alias_method :"prepend_#{callback}_filter", :"prepend_#{callback}_action"

        #nodyna <define_method-1311> <DM MODERATE (array)>
        define_method "skip_#{callback}_action" do |*names|
          _insert_callbacks(names) do |name, options|
            skip_callback(:process_action, callback, name, options)
          end
        end
        alias_method :"skip_#{callback}_filter", :"skip_#{callback}_action"

        alias_method :"append_#{callback}_action", :"#{callback}_action"
        alias_method :"append_#{callback}_filter", :"#{callback}_action"
      end
    end
  end
end
