require 'set'

module ActionController
  def self.add_renderer(key, &block)
    Renderers.add(key, &block)
  end

  def self.remove_renderer(key)
    Renderers.remove(key)
  end

  class MissingRenderer < LoadError
    def initialize(format)
      super "No renderer defined for format: #{format}"
    end
  end

  module Renderers
    extend ActiveSupport::Concern

    included do
      class_attribute :_renderers
      self._renderers = Set.new.freeze
    end

    module ClassMethods
      def use_renderers(*args)
        renderers = _renderers + args
        self._renderers = renderers.freeze
      end
      alias use_renderer use_renderers
    end

    def render_to_body(options)
      _render_to_body_with_renderer(options) || super
    end

    def _render_to_body_with_renderer(options)
      _renderers.each do |name|
        if options.key?(name)
          _process_options(options)
          method_name = Renderers._render_with_renderer_method_name(name)
          #nodyna <send-1306> <SD COMPLEX (change-prone variables)>
          return send(method_name, options.delete(name), options)
        end
      end
      nil
    end

    RENDERERS = Set.new

    def self._render_with_renderer_method_name(key)
      "_render_with_renderer_#{key}"
    end

    def self.add(key, &block)
      #nodyna <define_method-1307> <DM COMPLEX (events)>
      define_method(_render_with_renderer_method_name(key), &block)
      RENDERERS << key.to_sym
    end

    def self.remove(key)
      RENDERERS.delete(key.to_sym)
      method_name = _render_with_renderer_method_name(key)
      remove_method(method_name) if method_defined?(method_name)
    end

    module All
      extend ActiveSupport::Concern
      include Renderers

      included do
        self._renderers = RENDERERS
      end
    end

    add :json do |json, options|
      json = json.to_json(options) unless json.kind_of?(String)

      if options[:callback].present?
        if content_type.nil? || content_type == Mime::JSON
          self.content_type = Mime::JS
        end

        "/**/#{options[:callback]}(#{json})"
      else
        self.content_type ||= Mime::JSON
        json
      end
    end

    add :js do |js, options|
      self.content_type ||= Mime::JS
      js.respond_to?(:to_js) ? js.to_js(options) : js
    end

    add :xml do |xml, options|
      self.content_type ||= Mime::XML
      xml.respond_to?(:to_xml) ? xml.to_xml(options) : xml
    end
  end
end
