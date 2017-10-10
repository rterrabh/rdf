require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/string/filters'

module ActiveModel
  module Dirty
    extend ActiveSupport::Concern
    include ActiveModel::AttributeMethods

    included do
      attribute_method_suffix '_changed?', '_change', '_will_change!', '_was'
      attribute_method_affix prefix: 'reset_', suffix: '!'
      attribute_method_affix prefix: 'restore_', suffix: '!'
    end

    def changed?
      changed_attributes.present?
    end

    def changed
      changed_attributes.keys
    end

    def changes
      ActiveSupport::HashWithIndifferentAccess[changed.map { |attr| [attr, attribute_change(attr)] }]
    end

    def previous_changes
      @previously_changed ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    def changed_attributes
      @changed_attributes ||= ActiveSupport::HashWithIndifferentAccess.new
    end

    def attribute_changed?(attr, options = {}) #:nodoc:
      result = changes_include?(attr)
      result &&= options[:to] == __send__(attr) if options.key?(:to)
      result &&= options[:from] == changed_attributes[attr] if options.key?(:from)
      result
    end

    def attribute_was(attr) # :nodoc:
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end

    def restore_attributes(attributes = changed)
      attributes.each { |attr| restore_attribute! attr }
    end

    private

      def changes_include?(attr_name)
        attributes_changed_by_setter.include?(attr_name)
      end
      alias attribute_changed_by_setter? changes_include?

      def changes_applied # :doc:
        @previously_changed = changes
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      def clear_changes_information # :doc:
        @previously_changed = ActiveSupport::HashWithIndifferentAccess.new
        @changed_attributes = ActiveSupport::HashWithIndifferentAccess.new
      end

      def reset_changes
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          `#reset_changes` is deprecated and will be removed on Rails 5.
          Please use `#clear_changes_information` instead.
        MSG

        clear_changes_information
      end

      def attribute_change(attr)
        [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
      end

      def attribute_will_change!(attr)
        return if attribute_changed?(attr)

        begin
          value = __send__(attr)
          value = value.duplicable? ? value.clone : value
        rescue TypeError, NoMethodError
        end

        set_attribute_was(attr, value)
      end

      def reset_attribute!(attr)
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          `#reset_#{attr}!` is deprecated and will be removed on Rails 5.
          Please use `#restore_#{attr}!` instead.
        MSG

        restore_attribute!(attr)
      end

      def restore_attribute!(attr)
        if attribute_changed?(attr)
          __send__("#{attr}=", changed_attributes[attr])
          clear_attribute_changes([attr])
        end
      end

      alias_method :attributes_changed_by_setter, :changed_attributes # :nodoc:

      def set_attribute_was(attr, old_value)
        attributes_changed_by_setter[attr] = old_value
      end

      def clear_attribute_changes(attributes) # :doc:
        attributes_changed_by_setter.except!(*attributes)
      end
  end
end
