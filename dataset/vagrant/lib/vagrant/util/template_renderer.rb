require 'ostruct'
require "pathname"

require 'erubis'

module Vagrant
  module Util
    class TemplateRenderer < OpenStruct
      class << self
        def render(*args)
          render_with(:render, *args)
        end

        def render_string(*args)
          render_with(:render_string, *args)
        end

        def render_with(method, template, data={})
          renderer = new(template, data)
          yield renderer if block_given?
          #nodyna <send-3080> <SD MODERATE (change-prone variables)>
          renderer.send(method.to_sym)
        end
      end

      def initialize(template, data = {})
        super()

        @template_root = data.delete(:template_root)
        @template_root ||= Vagrant.source_root.join("templates")
        @template_root = Pathname.new(@template_root)

        data[:template] = template
        data.each do |key, value|
          #nodyna <send-3081> <SD COMPLEX (change-prone variables)>
          send("#{key}=", value)
        end
      end

      def render
        old_template = template
        result = nil
        File.open(full_template_path, 'r') do |f|
          self.template = f.read
          result = render_string
        end

        result
      ensure
        self.template = old_template
      end

      def render_string
        Erubis::Eruby.new(template, trim: true).result(binding)
      end

      def full_template_path
        @template_root.join("#{template}.erb").to_s.squeeze("/")
      end
    end
  end
end
