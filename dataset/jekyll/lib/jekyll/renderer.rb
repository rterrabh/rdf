
module Jekyll
  class Renderer

    attr_reader :document, :site, :site_payload

    def initialize(site, document, site_payload = nil)
      @site         = site
      @document     = document
      @site_payload = site_payload
    end

    def converters
      @converters ||= site.converters.select { |c| c.matches(document.extname) }
    end

    def output_ext
      converters.first.output_ext(document.extname)
    end


    def run
      payload = Utils.deep_merge_hashes({
        "page" => document.to_liquid
      }, site_payload || site.site_payload)

      Jekyll::Hooks.trigger document, :pre_render, payload

      info = {
        filters:   [Jekyll::Filters],
        registers: { :site => site, :page => payload['page'] }
      }

      payload["highlighter_prefix"] = converters.first.highlighter_prefix
      payload["highlighter_suffix"] = converters.first.highlighter_suffix

      output = document.content

      if document.render_with_liquid?
        output = render_liquid(output, payload, info, document.path)
      end

      output = convert(output)
      document.content = output

      if document.place_in_layout?
        place_in_layouts(
          output,
          payload,
          info
        )
      else
        output
      end
    end

    def convert(content)
      converters.reduce(content) do |output, converter|
        begin
          converter.convert output
        rescue => e
          Jekyll.logger.error "Conversion error:", "#{converter.class} encountered an error while converting '#{document.relative_path}':"
          Jekyll.logger.error("", e.to_s)
          raise e
        end
      end
    end

    def render_liquid(content, payload, info, path = nil)
      site.liquid_renderer.file(path).parse(content).render!(payload, info)
    rescue Tags::IncludeTagError => e
      Jekyll.logger.error "Liquid Exception:", "#{e.message} in #{e.path}, included in #{path || document.relative_path}"
      raise e
    rescue Exception => e
      Jekyll.logger.error "Liquid Exception:", "#{e.message} in #{path || document.relative_path}"
      raise e
    end

    def invalid_layout?(layout)
      !document.data["layout"].nil? && layout.nil?
    end

    def place_in_layouts(content, payload, info)
      output = content.dup
      layout = site.layouts[document.data["layout"]]

      Jekyll.logger.warn("Build Warning:", "Layout '#{document.data["layout"]}' requested in #{document.relative_path} does not exist.") if invalid_layout? layout

      used   = Set.new([layout])

      while layout
        payload = Utils.deep_merge_hashes(
          payload,
          {
            "content" => output,
            "page"    => document.to_liquid,
            "layout"  => layout.data
          }
        )

        output = render_liquid(
          layout.content,
          payload,
          info,
          File.join(site.config['layouts'], layout.name)
        )

        site.regenerator.add_dependency(
          site.in_source_dir(document.path),
          site.in_source_dir(layout.path)
        ) if document.write?

        if layout = site.layouts[layout.data["layout"]]
          if used.include?(layout)
            layout = nil # avoid recursive chain
          else
            used << layout
          end
        end
      end

      output
    end

  end
end
