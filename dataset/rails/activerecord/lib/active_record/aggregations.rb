module ActiveRecord
  module Aggregations # :nodoc:
    extend ActiveSupport::Concern

    def clear_aggregation_cache #:nodoc:
      @aggregation_cache.clear if persisted?
    end

    module ClassMethods
      def composed_of(part_id, options = {})
        options.assert_valid_keys(:class_name, :mapping, :allow_nil, :constructor, :converter)

        name        = part_id.id2name
        class_name  = options[:class_name]  || name.camelize
        mapping     = options[:mapping]     || [ name, name ]
        mapping     = [ mapping ] unless mapping.first.is_a?(Array)
        allow_nil   = options[:allow_nil]   || false
        constructor = options[:constructor] || :new
        converter   = options[:converter]

        reader_method(name, class_name, mapping, allow_nil, constructor)
        writer_method(name, class_name, mapping, allow_nil, converter)

        reflection = ActiveRecord::Reflection.create(:composed_of, part_id, nil, options, self)
        Reflection.add_aggregate_reflection self, part_id, reflection
      end

      private
        def reader_method(name, class_name, mapping, allow_nil, constructor)
          #nodyna <define_method-934> <DM MODERATE (events)>
          define_method(name) do
            if @aggregation_cache[name].nil? && (!allow_nil || mapping.any? {|key, _| !_read_attribute(key).nil? })
              attrs = mapping.collect {|key, _| _read_attribute(key)}
              object = constructor.respond_to?(:call) ?
                constructor.call(*attrs) :
                #nodyna <send-935> <SD COMPLEX (change-prone variables)>
                class_name.constantize.send(constructor, *attrs)
              @aggregation_cache[name] = object
            end
            @aggregation_cache[name]
          end
        end

        def writer_method(name, class_name, mapping, allow_nil, converter)
          #nodyna <define_method-936> <DM COMPLEX (events)>
          define_method("#{name}=") do |part|
            klass = class_name.constantize
            if part.is_a?(Hash)
              part = klass.new(*part.values)
            end

            unless part.is_a?(klass) || converter.nil? || part.nil?
              #nodyna <send-937> <SD COMPLEX (change-prone variables)>
              part = converter.respond_to?(:call) ? converter.call(part) : klass.send(converter, part)
            end

            if part.nil? && allow_nil
              mapping.each { |key, _| self[key] = nil }
              @aggregation_cache[name] = nil
            else
              #nodyna <send-938> <SD COMPLEX (array)>
              mapping.each { |key, value| self[key] = part.send(value) }
              @aggregation_cache[name] = part.freeze
            end
          end
        end
    end
  end
end
