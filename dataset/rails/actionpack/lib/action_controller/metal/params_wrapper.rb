require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/module/anonymous'
require 'active_support/core_ext/struct'
require 'action_dispatch/http/mime_type'

module ActionController
  module ParamsWrapper
    extend ActiveSupport::Concern

    EXCLUDE_PARAMETERS = %w(authenticity_token _method utf8)

    require 'mutex_m'

    class Options < Struct.new(:name, :format, :include, :exclude, :klass, :model) # :nodoc:
      include Mutex_m

      def self.from_hash(hash)
        name    = hash[:name]
        format  = Array(hash[:format])
        include = hash[:include] && Array(hash[:include]).collect(&:to_s)
        exclude = hash[:exclude] && Array(hash[:exclude]).collect(&:to_s)
        new name, format, include, exclude, nil, nil
      end

      def initialize(name, format, include, exclude, klass, model) # nodoc
        super
        @include_set = include
        @name_set    = name
      end

      def model
        super || synchronize { super || self.model = _default_wrap_model }
      end

      def include
        return super if @include_set

        m = model
        synchronize do
          return super if @include_set

          @include_set = true

          unless super || exclude
            if m.respond_to?(:attribute_names) && m.attribute_names.any?
              self.include = m.attribute_names
            end
          end
        end
      end

      def name
        return super if @name_set

        m = model
        synchronize do
          return super if @name_set

          @name_set = true

          unless super || klass.anonymous?
            self.name = m ? m.to_s.demodulize.underscore :
              klass.controller_name.singularize
          end
        end
      end

      private
      def _default_wrap_model #:nodoc:
        return nil if klass.anonymous?
        model_name = klass.name.sub(/Controller$/, '').classify

        begin
          if model_klass = model_name.safe_constantize
            model_klass
          else
            namespaces = model_name.split("::")
            namespaces.delete_at(-2)
            break if namespaces.last == model_name
            model_name = namespaces.join("::")
          end
        end until model_klass

        model_klass
      end
    end

    included do
      class_attribute :_wrapper_options
      self._wrapper_options = Options.from_hash(format: [])
    end

    module ClassMethods
      def _set_wrapper_options(options)
        self._wrapper_options = Options.from_hash(options)
      end

      def wrap_parameters(name_or_model_or_options, options = {})
        model = nil

        case name_or_model_or_options
        when Hash
          options = name_or_model_or_options
        when false
          options = options.merge(:format => [])
        when Symbol, String
          options = options.merge(:name => name_or_model_or_options)
        else
          model = name_or_model_or_options
        end

        opts   = Options.from_hash _wrapper_options.to_h.slice(:format).merge(options)
        opts.model = model
        opts.klass = self

        self._wrapper_options = opts
      end

      def inherited(klass)
        if klass._wrapper_options.format.any?
          params = klass._wrapper_options.dup
          params.klass = klass
          klass._wrapper_options = params
        end
        super
      end
    end

    def process_action(*args)
      if _wrapper_enabled?
        if request.parameters[_wrapper_key].present?
          wrapped_hash = _extract_parameters(request.parameters)
        else
          wrapped_hash = _wrap_parameters request.request_parameters
        end

        wrapped_keys = request.request_parameters.keys
        wrapped_filtered_hash = _wrap_parameters request.filtered_parameters.slice(*wrapped_keys)

        request.parameters.merge! wrapped_hash
        request.request_parameters.merge! wrapped_hash

        request.filtered_parameters.merge! wrapped_filtered_hash
      end
      super
    end

    private

      def _wrapper_key
        _wrapper_options.name
      end

      def _wrapper_formats
        _wrapper_options.format
      end

      def _wrap_parameters(parameters)
        { _wrapper_key => _extract_parameters(parameters) }
      end

      def _extract_parameters(parameters)
        if include_only = _wrapper_options.include
          parameters.slice(*include_only)
        else
          exclude = _wrapper_options.exclude || []
          parameters.except(*(exclude + EXCLUDE_PARAMETERS))
        end
      end

      def _wrapper_enabled?
        ref = request.content_mime_type.try(:ref)
        _wrapper_formats.include?(ref) && _wrapper_key && !request.request_parameters[_wrapper_key]
      end
  end
end
