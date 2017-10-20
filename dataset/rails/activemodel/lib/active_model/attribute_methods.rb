require 'thread_safe'
require 'mutex_m'

module ActiveModel
  class MissingAttributeError < NoMethodError
  end

  module AttributeMethods
    extend ActiveSupport::Concern

    NAME_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?=]?\z/
    CALL_COMPILABLE_REGEXP = /\A[a-zA-Z_]\w*[!?]?\z/

    included do
      class_attribute :attribute_aliases, :attribute_method_matchers, instance_writer: false
      self.attribute_aliases = {}
      self.attribute_method_matchers = [ClassMethods::AttributeMethodMatcher.new]
    end

    module ClassMethods
      def attribute_method_prefix(*prefixes)
        self.attribute_method_matchers += prefixes.map! { |prefix| AttributeMethodMatcher.new prefix: prefix }
        undefine_attribute_methods
      end

      def attribute_method_suffix(*suffixes)
        self.attribute_method_matchers += suffixes.map! { |suffix| AttributeMethodMatcher.new suffix: suffix }
        undefine_attribute_methods
      end

      def attribute_method_affix(*affixes)
        self.attribute_method_matchers += affixes.map! { |affix| AttributeMethodMatcher.new prefix: affix[:prefix], suffix: affix[:suffix] }
        undefine_attribute_methods
      end

      def alias_attribute(new_name, old_name)
        self.attribute_aliases = attribute_aliases.merge(new_name.to_s => old_name.to_s)
        attribute_method_matchers.each do |matcher|
          matcher_new = matcher.method_name(new_name).to_s
          matcher_old = matcher.method_name(old_name).to_s
          define_proxy_call false, self, matcher_new, matcher_old
        end
      end

      def attribute_alias?(new_name)
        attribute_aliases.key? new_name.to_s
      end

      def attribute_alias(name)
        attribute_aliases[name.to_s]
      end

      def define_attribute_methods(*attr_names)
        attr_names.flatten.each { |attr_name| define_attribute_method(attr_name) }
      end

      def define_attribute_method(attr_name)
        attribute_method_matchers.each do |matcher|
          method_name = matcher.method_name(attr_name)

          unless instance_method_already_implemented?(method_name)
            generate_method = "define_method_#{matcher.method_missing_target}"

            if respond_to?(generate_method, true)
              #nodyna <send-964> <SD COMPLEX (change-prone variables)>
              send(generate_method, attr_name)
            else
              define_proxy_call true, generated_attribute_methods, method_name, matcher.method_missing_target, attr_name.to_s
            end
          end
        end
        attribute_method_matchers_cache.clear
      end

      def undefine_attribute_methods
        #nodyna <module_eval-965> <ME COMPLEX (block execution)>
        generated_attribute_methods.module_eval do
          instance_methods.each { |m| undef_method(m) }
        end
        attribute_method_matchers_cache.clear
      end

      def generated_attribute_methods #:nodoc:
        @generated_attribute_methods ||= Module.new {
          extend Mutex_m
        }.tap { |mod| include mod }
      end

      protected
        def instance_method_already_implemented?(method_name) #:nodoc:
          generated_attribute_methods.method_defined?(method_name)
        end

      private
        def attribute_method_matchers_cache #:nodoc:
          @attribute_method_matchers_cache ||= ThreadSafe::Cache.new(initial_capacity: 4)
        end

        def attribute_method_matchers_matching(method_name) #:nodoc:
          attribute_method_matchers_cache.compute_if_absent(method_name) do
            matchers = attribute_method_matchers.partition(&:plain?).reverse.flatten(1)
            matchers.map { |method| method.match(method_name) }.compact
          end
        end

        def define_proxy_call(include_private, mod, name, send, *extra) #:nodoc:
          defn = if name =~ NAME_COMPILABLE_REGEXP
            "def #{name}(*args)"
          else
            "define_method(:'#{name}') do |*args|"
          end

          extra = (extra.map!(&:inspect) << "*args").join(", ")

          target = if send =~ CALL_COMPILABLE_REGEXP
            "#{"self." unless include_private}#{send}(#{extra})"
          else
            "send(:'#{send}', #{extra})"
          end

          #nodyna <module_eval-972> <ME COMPLEX (block execution)>
          mod.module_eval <<-RUBY, __FILE__, __LINE__ + 1
            end
          RUBY
        end

        class AttributeMethodMatcher #:nodoc:
          attr_reader :prefix, :suffix, :method_missing_target

          AttributeMethodMatch = Struct.new(:target, :attr_name, :method_name)

          def initialize(options = {})
            @prefix, @suffix = options.fetch(:prefix, ''), options.fetch(:suffix, '')
            @regex = /^(?:#{Regexp.escape(@prefix)})(.*)(?:#{Regexp.escape(@suffix)})$/
            @method_missing_target = "#{@prefix}attribute#{@suffix}"
            @method_name = "#{prefix}%s#{suffix}"
          end

          def match(method_name)
            if @regex =~ method_name
              AttributeMethodMatch.new(method_missing_target, $1, method_name)
            end
          end

          def method_name(attr_name)
            @method_name % attr_name
          end

          def plain?
            prefix.empty? && suffix.empty?
          end
        end
    end

    def method_missing(method, *args, &block)
      if respond_to_without_attributes?(method, true)
        super
      else
        match = match_attribute_method?(method.to_s)
        match ? attribute_missing(match, *args, &block) : super
      end
    end

    def attribute_missing(match, *args, &block)
      __send__(match.target, match.attr_name, *args, &block)
    end

    alias :respond_to_without_attributes? :respond_to?
    def respond_to?(method, include_private_methods = false)
      if super
        true
      elsif !include_private_methods && super(method, true)
        false
      else
        !match_attribute_method?(method.to_s).nil?
      end
    end

    protected
      def attribute_method?(attr_name) #:nodoc:
        respond_to_without_attributes?(:attributes) && attributes.include?(attr_name)
      end

    private
      def match_attribute_method?(method_name)
        #nodyna <send-973> <SD EASY (private methods)>
        matches = self.class.send(:attribute_method_matchers_matching, method_name)
        matches.detect { |match| attribute_method?(match.attr_name) }
      end

      def missing_attribute(attr_name, stack)
        raise ActiveModel::MissingAttributeError, "missing attribute: #{attr_name}", stack
      end
  end
end
