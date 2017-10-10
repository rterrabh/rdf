require 'yaml'

YAML.add_builtin_type("omap") do |type, val|
  ActiveSupport::OrderedHash[val.map{ |v| v.to_a.first }]
end

module ActiveSupport
  class OrderedHash < ::Hash
    def to_yaml_type
      "!tag:yaml.org,2002:omap"
    end

    def encode_with(coder)
      coder.represent_seq '!omap', map { |k,v| { k => v } }
    end

    def select(*args, &block)
      dup.tap { |hash| hash.select!(*args, &block) }
    end

    def reject(*args, &block)
      dup.tap { |hash| hash.reject!(*args, &block) }
    end

    def nested_under_indifferent_access
      self
    end

    def extractable_options?
      true
    end
  end
end
