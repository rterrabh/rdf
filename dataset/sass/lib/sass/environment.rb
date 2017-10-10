require 'set'

module Sass
  class BaseEnvironment
    class << self
      def inherited_hash_accessor(name)
        inherited_hash_reader(name)
        inherited_hash_writer(name)
      end

      def inherited_hash_reader(name)
        #nodyna <class_eval-2983> <not yet classified>
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}(name)
            _#{name}(name.tr('_', '-'))
          end

          def _#{name}(name)
            (@#{name}s && @#{name}s[name]) || @parent && @parent._#{name}(name)
          end
          protected :_#{name}

          def is_#{name}_global?(name)
            return !@parent if @#{name}s && @#{name}s.has_key?(name)
            @parent && @parent.is_#{name}_global?(name)
          end
        RUBY
      end

      def inherited_hash_writer(name)
        #nodyna <class_eval-2984> <not yet classified>
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def set_#{name}(name, value)
            name = name.tr('_', '-')
            @#{name}s[name] = value unless try_set_#{name}(name, value)
          end

          def try_set_#{name}(name, value)
            @#{name}s ||= {}
            if @#{name}s.include?(name)
              @#{name}s[name] = value
              true
            elsif @parent && !@parent.global?
              @parent.try_set_#{name}(name, value)
            else
              false
            end
          end
          protected :try_set_#{name}

          def set_local_#{name}(name, value)
            @#{name}s ||= {}
            @#{name}s[name.tr('_', '-')] = value
          end

          def set_global_#{name}(name, value)
            global_env.set_#{name}(name, value)
          end
        RUBY
      end
    end

    attr_reader :options

    attr_writer :caller
    attr_writer :content
    attr_writer :selector

    inherited_hash_reader :var

    inherited_hash_reader :mixin

    inherited_hash_reader :function

    def initialize(parent = nil, options = nil)
      @parent = parent
      @options = options || (parent && parent.options) || {}
      @stack = Sass::Stack.new if @parent.nil?
    end

    def global?
      @parent.nil?
    end

    def caller
      @caller || (@parent && @parent.caller)
    end

    def content
      @content || (@parent && @parent.content)
    end

    def selector
      @selector || (@caller && @caller.selector) || (@parent && @parent.selector)
    end

    def global_env
      @global_env ||= global? ? self : @parent.global_env
    end

    def stack
      @stack || global_env.stack
    end
  end

  class Environment < BaseEnvironment
    attr_reader :parent

    inherited_hash_writer :var

    inherited_hash_writer :mixin

    inherited_hash_writer :function
  end

  class ReadOnlyEnvironment < BaseEnvironment
    def caller
      return @caller if @caller
      env = super
      @caller ||= env.is_a?(ReadOnlyEnvironment) ? env : ReadOnlyEnvironment.new(env, env.options)
    end

    def content
      return @content if @content
      env = super
      @content ||= env.is_a?(ReadOnlyEnvironment) ? env : ReadOnlyEnvironment.new(env, env.options)
    end
  end

  class SemiGlobalEnvironment < Environment
    def try_set_var(name, value)
      @vars ||= {}
      if @vars.include?(name)
        @vars[name] = value
        true
      elsif @parent
        @parent.try_set_var(name, value)
      else
        false
      end
    end
  end
end
