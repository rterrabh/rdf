module Grape
  module ParameterTypes
    PRIMITIVES = [
      Integer,
      Float,
      BigDecimal,
      Numeric,

      Date,
      DateTime,
      Time,

      Virtus::Attribute::Boolean,
      String,
      Symbol,
      Rack::Multipart::UploadedFile
    ]

    STRUCTURES = [
      Hash,
      Array,
      Set
    ]

    def self.primitive?(type)
      PRIMITIVES.include?(type)
    end

    def self.structure?(type)
      STRUCTURES.include?(type)
    end

    def self.custom_type?(type)
      !primitive?(type) &&
        !structure?(type) &&
        type.respond_to?(:parse) &&
        type.method(:parse).arity == 1
    end
  end
end
