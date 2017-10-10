module ActiveRecord
  module Scoping
    module Default
      extend ActiveSupport::Concern

      included do
        class_attribute :default_scopes, instance_writer: false, instance_predicate: false

        self.default_scopes = []
      end

      module ClassMethods
        def unscoped
          block_given? ? relation.scoping { yield } : relation
        end

        def before_remove_const #:nodoc:
          self.current_scope = nil
        end

        protected

        def default_scope(scope = nil)
          scope = Proc.new if block_given?

          if scope.is_a?(Relation) || !scope.respond_to?(:call)
            raise ArgumentError,
              "Support for calling #default_scope without a block is removed. For example instead " \
              "of `default_scope where(color: 'red')`, please use " \
              "`default_scope { where(color: 'red') }`. (Alternatively you can just redefine " \
              "self.default_scope.)"
          end

          self.default_scopes += [scope]
        end

        def build_default_scope(base_rel = relation) # :nodoc:
          return if abstract_class?
          if !Base.is_a?(method(:default_scope).owner)
            evaluate_default_scope { default_scope }
          elsif default_scopes.any?
            evaluate_default_scope do
              default_scopes.inject(base_rel) do |default_scope, scope|
                default_scope.merge(base_rel.scoping { scope.call })
              end
            end
          end
        end

        def ignore_default_scope? # :nodoc:
          ScopeRegistry.value_for(:ignore_default_scope, self)
        end

        def ignore_default_scope=(ignore) # :nodoc:
          ScopeRegistry.set_value_for(:ignore_default_scope, self, ignore)
        end

        def evaluate_default_scope # :nodoc:
          return if ignore_default_scope?

          begin
            self.ignore_default_scope = true
            yield
          ensure
            self.ignore_default_scope = false
          end
        end
      end
    end
  end
end
