require 'active_support/core_ext/array'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/kernel/singleton_class'

module ActiveRecord
  module Scoping
    module Named
      extend ActiveSupport::Concern

      module ClassMethods
        def all
          if current_scope
            current_scope.clone
          else
            default_scoped
          end
        end

        def default_scoped # :nodoc:
          relation.merge(build_default_scope)
        end

        def scope_attributes # :nodoc:
          all.scope_for_create
        end

        def scope_attributes? # :nodoc:
          current_scope || default_scopes.any?
        end

        def scope(name, body, &block)
          unless body.respond_to?(:call)
            raise ArgumentError, 'The scope body needs to be callable.'
          end

          if dangerous_class_method?(name)
            raise ArgumentError, "You tried to define a scope named \"#{name}\" " \
              "on the model \"#{self.name}\", but Active Record already defined " \
              "a class method with the same name."
          end

          extension = Module.new(&block) if block

          #nodyna <send-772> <SD COMPLEX (private methods)>
          #nodyna <define_method-773> <DM COMPLEX (events)>
          singleton_class.send(:define_method, name) do |*args|
            scope = all.scoping { body.call(*args) }
            scope = scope.extending(extension) if extension

            scope || all
          end
        end
      end
    end
  end
end
