require 'erubis'
require 'set'
require 'active_support/configurable'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/module/anonymous'

module AbstractController
  class Error < StandardError #:nodoc:
  end

  class ActionNotFound < StandardError
  end

  class Base
    attr_internal :response_body
    attr_internal :action_name
    attr_internal :formats

    include ActiveSupport::Configurable
    extend ActiveSupport::DescendantsTracker

    undef_method :not_implemented
    class << self
      attr_reader :abstract
      alias_method :abstract?, :abstract

      def abstract!
        @abstract = true
      end

      def inherited(klass) # :nodoc:
        unless klass.instance_variable_defined?(:@abstract)
          #nodyna <instance_variable_set-1315> <IVS COMPLEX (variable definition)>
          klass.instance_variable_set(:@abstract, false)
        end
        super
      end

      def internal_methods
        controller = self

        controller = controller.superclass until controller.abstract?
        controller.public_instance_methods(true)
      end

      def hidden_actions
        []
      end

      def action_methods
        @action_methods ||= begin
          methods = (public_instance_methods(true) -
            internal_methods +
            public_instance_methods(false)).uniq.map { |x| x.to_s } -
            hidden_actions.to_a

          Set.new(methods.reject { |method| method =~ /_one_time_conditions/ })
        end
      end

      def clear_action_methods!
        @action_methods = nil
      end

      def controller_path
        @controller_path ||= name.sub(/Controller$/, '').underscore unless anonymous?
      end

      def method_added(name)
        super
        clear_action_methods!
      end
    end

    abstract!

    def process(action, *args)
      @_action_name = action.to_s

      unless action_name = _find_action_name(@_action_name)
        raise ActionNotFound, "The action '#{action}' could not be found for #{self.class.name}"
      end

      @_response_body = nil

      process_action(action_name, *args)
    end

    def controller_path
      self.class.controller_path
    end

    def action_methods
      self.class.action_methods
    end

    def available_action?(action_name)
      _find_action_name(action_name).present?
    end

    def self.supports_path?
      true
    end

    private

      def action_method?(name)
        self.class.action_methods.include?(name)
      end

      def process_action(method_name, *args)
        send_action(method_name, *args)
      end

      alias send_action send

      def _handle_action_missing(*args)
        action_missing(@_action_name, *args)
      end

      def _find_action_name(action_name)
        _valid_action_name?(action_name) && method_for_action(action_name)
      end

      def method_for_action(action_name)
        if action_method?(action_name)
          action_name
        elsif respond_to?(:action_missing, true)
          "_handle_action_missing"
        end
      end

      def _valid_action_name?(action_name)
        !action_name.to_s.include? File::SEPARATOR
      end
  end
end
