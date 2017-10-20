require "action_view/rendering"
require "active_support/core_ext/module/remove_method"

module ActionView
  module Layouts
    extend ActiveSupport::Concern

    include ActionView::Rendering

    included do
      class_attribute :_layout, :_layout_conditions, :instance_accessor => false
      self._layout = nil
      self._layout_conditions = {}
      _write_layout_method
    end

    delegate :_layout_conditions, to: :class

    module ClassMethods
      def inherited(klass) # :nodoc:
        super
        klass._write_layout_method
      end

      module LayoutConditions # :nodoc:
        private

        def _conditional_layout?
          return unless super

          conditions = _layout_conditions

          if only = conditions[:only]
            only.include?(action_name)
          elsif except = conditions[:except]
            !except.include?(action_name)
          else
            true
          end
        end
      end

      def layout(layout, conditions = {})
        include LayoutConditions unless conditions.empty?

        conditions.each {|k, v| conditions[k] = Array(v).map {|a| a.to_s} }
        self._layout_conditions = conditions

        self._layout = layout
        _write_layout_method
      end

      def _write_layout_method # :nodoc:
        remove_possible_method(:_layout)

        prefixes    = _implied_layout_name =~ /\blayouts/ ? [] : ["layouts"]
        default_behavior = "lookup_context.find_all('#{_implied_layout_name}', #{prefixes.inspect}).first || super"
        name_clause = if name
          default_behavior
        else
          <<-RUBY
            super
          RUBY
        end

        layout_definition = case _layout
          when String
            _layout.inspect
          when Symbol
            <<-RUBY
                return #{default_behavior} if layout.nil?
                unless layout.is_a?(String) || !layout
                  raise ArgumentError, "Your layout method :#{_layout} returned \#{layout}. It " \
                    "should have returned a String, false, or nil"
                end
              end
            RUBY
          when Proc
            #nodyna <define_method-1197> <DM MODERATE (events)>
            define_method :_layout_from_proc, &_layout
            protected :_layout_from_proc
            <<-RUBY
              result = _layout_from_proc(#{_layout.arity == 0 ? '' : 'self'})
              return #{default_behavior} if result.nil?
              result
            RUBY
          when false
            nil
          when true
            raise ArgumentError, "Layouts must be specified as a String, Symbol, Proc, false, or nil"
          when nil
            name_clause
        end

        #nodyna <class_eval-1198> <CE TRIVIAL (define methods)>
        self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def _layout
            if _conditional_layout?
            else
            end
          end
          private :_layout
        RUBY
      end

      private

      def _implied_layout_name # :nodoc:
        controller_path
      end
    end

    def _normalize_options(options) # :nodoc:
      super

      if _include_layout?(options)
        layout = options.delete(:layout) { :default }
        options[:layout] = _layout_for_option(layout)
      end
    end

    attr_internal_writer :action_has_layout

    def initialize(*) # :nodoc:
      @_action_has_layout = true
      super
    end

    def action_has_layout?
      @_action_has_layout
    end

  private

    def _conditional_layout?
      true
    end

    def _layout; end

    def _layout_for_option(name)
      case name
      when String     then _normalize_layout(name)
      when Proc       then name
      when true       then Proc.new { _default_layout(true)  }
      when :default   then Proc.new { _default_layout(false) }
      when false, nil then nil
      else
        raise ArgumentError,
          "String, Proc, :default, true, or false, expected for `layout'; you passed #{name.inspect}"
      end
    end

    def _normalize_layout(value)
      value.is_a?(String) && value !~ /\blayouts/ ? "layouts/#{value}" : value
    end

    def _default_layout(require_layout = false)
      begin
        value = _layout if action_has_layout?
      rescue NameError => e
        raise e, "Could not render layout: #{e.message}"
      end

      if require_layout && action_has_layout? && !value
        raise ArgumentError,
          "There was no default layout for #{self.class} in #{view_paths.inspect}"
      end

      _normalize_layout(value)
    end

    def _include_layout?(options)
      (options.keys & [:body, :text, :plain, :html, :inline, :partial]).empty? || options.key?(:layout)
    end
  end
end
