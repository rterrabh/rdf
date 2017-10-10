module ActiveModel
  module Lint
    module Tests

      def test_to_key
        assert model.respond_to?(:to_key), "The model should respond to to_key"
        def model.persisted?() false end
        assert model.to_key.nil?, "to_key should return nil when `persisted?` returns false"
      end

      def test_to_param
        assert model.respond_to?(:to_param), "The model should respond to to_param"
        def model.to_key() [1] end
        def model.persisted?() false end
        assert model.to_param.nil?, "to_param should return nil when `persisted?` returns false"
      end

      def test_to_partial_path
        assert model.respond_to?(:to_partial_path), "The model should respond to to_partial_path"
        assert_kind_of String, model.to_partial_path
      end

      def test_persisted?
        assert model.respond_to?(:persisted?), "The model should respond to persisted?"
        assert_boolean model.persisted?, "persisted?"
      end

      def test_model_naming
        assert model.class.respond_to?(:model_name), "The model class should respond to model_name"
        model_name = model.class.model_name
        assert model_name.respond_to?(:to_str)
        assert model_name.human.respond_to?(:to_str)
        assert model_name.singular.respond_to?(:to_str)
        assert model_name.plural.respond_to?(:to_str)

        assert model.respond_to?(:model_name), "The model instance should respond to model_name"
        assert_equal model.model_name, model.class.model_name
      end

      def test_errors_aref
        assert model.respond_to?(:errors), "The model should respond to errors"
        assert model.errors[:hello].is_a?(Array), "errors#[] should return an Array"
      end

      private
        def model
          assert @model.respond_to?(:to_model), "The object should respond to to_model"
          @model.to_model
        end

        def assert_boolean(result, name)
          assert result == true || result == false, "#{name} should be a boolean"
        end
    end
  end
end
