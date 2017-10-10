module SimpleForm
  module Inputs
    class CollectionInput < Base
      def self.boolean_collection
        i18n_cache :boolean_collection do
          [ [I18n.t(:"simple_form.yes", default: 'Yes'), true],
            [I18n.t(:"simple_form.no", default: 'No'), false] ]
        end
      end

      def input(wrapper_options = nil)
        raise NotImplementedError,
          "input should be implemented by classes inheriting from CollectionInput"
      end

      def input_options
        options = super

        options[:include_blank] = true unless skip_include_blank?

        [:prompt, :include_blank].each do |key|
          translate_option options, key
        end

        options
      end

      private

      def collection
        @collection ||= begin
          collection = options.delete(:collection) || self.class.boolean_collection
          collection.respond_to?(:call) ? collection.call : collection.to_a
        end
      end

      def has_required?
        super && (input_options[:include_blank] || input_options[:prompt] || multiple?)
      end

      def skip_include_blank?
        (options.keys & [:prompt, :include_blank, :default, :selected]).any? || multiple?
      end

      def multiple?
        !!options[:input_html].try(:[], :multiple)
      end

      def detect_collection_methods
        label, value = options.delete(:label_method), options.delete(:value_method)

        unless label && value
          common_method_for = detect_common_display_methods
          label ||= common_method_for[:label]
          value ||= common_method_for[:value]
        end

        [label, value]
      end

      def detect_common_display_methods(collection_classes = detect_collection_classes)
        collection_translated = translate_collection if collection_classes == [Symbol]

        if collection_translated || collection_classes.include?(Array)
          { label: :first, value: :second }
        elsif collection_includes_basic_objects?(collection_classes)
          { label: :to_s, value: :to_s }
        else
          detect_method_from_class(collection_classes)
        end
      end

      def detect_method_from_class(collection_classes)
        sample = collection.first || collection.last

        { label: SimpleForm.collection_label_methods.find { |m| sample.respond_to?(m) },
          value: SimpleForm.collection_value_methods.find { |m| sample.respond_to?(m) } }
      end

      def detect_collection_classes(some_collection = collection)
        some_collection.map { |e| e.class }.uniq
      end

      def collection_includes_basic_objects?(collection_classes)
        (collection_classes & [
          String, Integer, Fixnum, Bignum, Float, NilClass, Symbol, TrueClass, FalseClass
        ]).any?
      end

      def translate_collection
        if translated_collection = translate_from_namespace(:options)
          @collection = collection.map do |key|
            html_key = "#{key}_html".to_sym

            if translated_collection[html_key]
              [translated_collection[html_key].html_safe || key, key.to_s]
            else
              [translated_collection[key] || key, key.to_s]
            end
          end
          true
        end
      end

      def translate_option(options, key)
        if options[key] == :translate
          namespace = key.to_s.pluralize

          options[key] = translate_from_namespace(namespace, true)
        end
      end
    end
  end
end
