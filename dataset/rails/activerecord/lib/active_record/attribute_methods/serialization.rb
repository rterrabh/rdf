require 'active_support/core_ext/string/filters'

module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      module ClassMethods
        def serialize(attr_name, class_name_or_coder = Object)
          coder = if class_name_or_coder == ::JSON
                    Coders::JSON
                  elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
                    class_name_or_coder
                  else
                    Coders::YAMLColumn.new(class_name_or_coder)
                  end

          decorate_attribute_type(attr_name, :serialize) do |type|
            Type::Serialized.new(type, coder)
          end
        end

        def serialized_attributes
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            `serialized_attributes` is deprecated without replacement, and will
            be removed in Rails 5.0.
          MSG

          @serialized_attributes ||= Hash[
            columns.select { |t| t.cast_type.is_a?(Type::Serialized) }.map { |c|
              [c.name, c.cast_type.coder]
            }
          ]
        end
      end
    end
  end
end
