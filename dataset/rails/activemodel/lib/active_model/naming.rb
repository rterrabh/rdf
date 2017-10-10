require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/module/remove_method'

module ActiveModel
  class Name
    include Comparable

    attr_reader :singular, :plural, :element, :collection,
      :singular_route_key, :route_key, :param_key, :i18n_key,
      :name

    alias_method :cache_key, :collection








    delegate :==, :===, :<=>, :=~, :"!~", :eql?, :to_s,
             :to_str, :as_json, to: :name

    def initialize(klass, namespace = nil, name = nil)
      @name = name || klass.name

      raise ArgumentError, "Class name cannot be blank. You need to supply a name argument when anonymous class given" if @name.blank?

      @unnamespaced = @name.sub(/^#{namespace.name}::/, '') if namespace
      @klass        = klass
      @singular     = _singularize(@name)
      @plural       = ActiveSupport::Inflector.pluralize(@singular)
      @element      = ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.demodulize(@name))
      @human        = ActiveSupport::Inflector.humanize(@element)
      @collection   = ActiveSupport::Inflector.tableize(@name)
      @param_key    = (namespace ? _singularize(@unnamespaced) : @singular)
      @i18n_key     = @name.underscore.to_sym

      @route_key          = (namespace ? ActiveSupport::Inflector.pluralize(@param_key) : @plural.dup)
      @singular_route_key = ActiveSupport::Inflector.singularize(@route_key)
      @route_key << "_index" if @plural == @singular
    end

    def human(options={})
      return @human unless @klass.respond_to?(:lookup_ancestors) &&
                           @klass.respond_to?(:i18n_scope)

      defaults = @klass.lookup_ancestors.map do |klass|
        klass.model_name.i18n_key
      end

      defaults << options[:default] if options[:default]
      defaults << @human

      options = { scope: [@klass.i18n_scope, :models], count: 1, default: defaults }.merge!(options.except(:default))
      I18n.translate(defaults.shift, options)
    end

    private

    def _singularize(string, replacement='_')
      ActiveSupport::Inflector.underscore(string).tr('/', replacement)
    end
  end

  module Naming
    def self.extended(base) #:nodoc:
      base.remove_possible_method :model_name
      base.delegate :model_name, to: :class
    end

    def model_name
      @_model_name ||= begin
        namespace = self.parents.detect do |n|
          n.respond_to?(:use_relative_model_naming?) && n.use_relative_model_naming?
        end
        ActiveModel::Name.new(self, namespace)
      end
    end

    def self.plural(record_or_class)
      model_name_from_record_or_class(record_or_class).plural
    end

    def self.singular(record_or_class)
      model_name_from_record_or_class(record_or_class).singular
    end

    def self.uncountable?(record_or_class)
      plural(record_or_class) == singular(record_or_class)
    end

    def self.singular_route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).singular_route_key
    end

    def self.route_key(record_or_class)
      model_name_from_record_or_class(record_or_class).route_key
    end

    def self.param_key(record_or_class)
      model_name_from_record_or_class(record_or_class).param_key
    end

    def self.model_name_from_record_or_class(record_or_class) #:nodoc:
      if record_or_class.respond_to?(:to_model)
        record_or_class.to_model.model_name
      else
        record_or_class.model_name
      end
    end
    private_class_method :model_name_from_record_or_class
  end
end
