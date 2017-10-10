require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'action_view/helpers/asset_url_helper'
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers #:nodoc:
    module AssetTagHelper
      extend ActiveSupport::Concern

      include AssetUrlHelper
      include TagHelper

      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!('protocol', 'extname').symbolize_keys
        sources.uniq.map { |source|
          tag_options = {
            "src" => path_to_javascript(source, path_options)
          }.merge!(options)
          content_tag(:script, "", tag_options)
        }.join("\n").html_safe
      end

      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!('protocol').symbolize_keys

        sources.uniq.map { |source|
          tag_options = {
            "rel" => "stylesheet",
            "media" => "screen",
            "href" => path_to_stylesheet(source, path_options)
          }.merge!(options)
          tag(:link, tag_options)
        }.join("\n").html_safe
      end

      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        if !(type == :rss || type == :atom) && tag_options[:type].blank?
          raise ArgumentError.new("You should pass :type tag_option key explicitly, because you have passed #{type} type other than :rss or :atom.")
        end

        tag(
          "link",
          "rel"   => tag_options[:rel] || "alternate",
          "type"  => tag_options[:type] || Mime::Type.lookup_by_extension(type.to_s).to_s,
          "title" => tag_options[:title] || type.to_s.upcase,
          "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
        )
      end

      def favicon_link_tag(source='favicon.ico', options={})
        tag('link', {
          :rel  => 'shortcut icon',
          :type => 'image/x-icon',
          :href => path_to_image(source)
        }.merge!(options.symbolize_keys))
      end

      def image_tag(source, options={})
        options = options.symbolize_keys

        src = options[:src] = path_to_image(source)

        unless src =~ /^(?:cid|data):/ || src.blank?
          options[:alt] = options.fetch(:alt){ image_alt(src) }
        end

        options[:width], options[:height] = extract_dimensions(options.delete(:size)) if options[:size]
        tag("img", options)
      end

      def image_alt(src)
        File.basename(src, '.*').sub(/-[[:xdigit:]]{32}\z/, '').tr('-_', ' ').capitalize
      end

      def video_tag(*sources)
        multiple_sources_tag('video', sources) do |options|
          options[:poster] = path_to_image(options[:poster]) if options[:poster]
          options[:width], options[:height] = extract_dimensions(options.delete(:size)) if options[:size]
        end
      end

      def audio_tag(*sources)
        multiple_sources_tag('audio', sources)
      end

      private
        def multiple_sources_tag(type, sources)
          options = sources.extract_options!.symbolize_keys
          sources.flatten!

          yield options if block_given?

          if sources.size > 1
            content_tag(type, options) do
              #nodyna <send-1226> <SD MODERATE (array)>
              safe_join sources.map { |source| tag("source", :src => send("path_to_#{type}", source)) }
            end
          else
            #nodyna <send-1227> <SD MODERATE (change-prone variables)>
            options[:src] = send("path_to_#{type}", sources.first)
            content_tag(type, nil, options)
          end
        end

        def extract_dimensions(size)
          if size =~ %r{\A\d+x\d+\z}
            size.split('x')
          elsif size =~ %r{\A\d+\z}
            [size, size]
          end
        end
    end
  end
end
