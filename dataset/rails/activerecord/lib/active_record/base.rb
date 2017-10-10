require 'yaml'
require 'set'
require 'active_support/benchmarkable'
require 'active_support/dependencies'
require 'active_support/descendants_tracker'
require 'active_support/time'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/delegating_attributes'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/transform_values'
require 'active_support/core_ext/string/behavior'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/object/duplicable'
require 'active_support/core_ext/class/subclasses'
require 'arel'
require 'active_record/attribute_decorators'
require 'active_record/errors'
require 'active_record/log_subscriber'
require 'active_record/explain_subscriber'
require 'active_record/relation/delegation'
require 'active_record/attributes'

module ActiveRecord #:nodoc:
  class Base
    extend ActiveModel::Naming

    extend ActiveSupport::Benchmarkable
    extend ActiveSupport::DescendantsTracker

    extend ConnectionHandling
    extend QueryCache::ClassMethods
    extend Querying
    extend Translation
    extend DynamicMatchers
    extend Explain
    extend Enum
    extend Delegation::DelegateCache

    include Core
    include Persistence
    include ReadonlyAttributes
    include ModelSchema
    include Inheritance
    include Scoping
    include Sanitization
    include AttributeAssignment
    include ActiveModel::Conversion
    include Integration
    include Validations
    include CounterCache
    include Attributes
    include AttributeDecorators
    include Locking::Optimistic
    include Locking::Pessimistic
    include AttributeMethods
    include Callbacks
    include Timestamp
    include Associations
    include ActiveModel::SecurePassword
    include AutosaveAssociation
    include NestedAttributes
    include Aggregations
    include Transactions
    include NoTouching
    include Reflection
    include Serialization
    include Store
  end

  ActiveSupport.run_load_hooks(:active_record, Base)
end
