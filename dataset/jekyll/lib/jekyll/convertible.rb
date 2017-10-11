
require 'set'


module Jekyll
  module Convertible
    def to_s
      content || ''
    end

    def published?
      !(data.key?('published') && data['published'] == false)
    end

    def merged_file_read_opts(opts)
      (site ? site.file_read_opts : {}).merge(opts)
    end

    def read_yaml(base, name, opts = {})
      begin
        self.content = File.read(site.in_source_dir(base, name),
                                 merged_file_read_opts(opts))
        if content =~ /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
          self.content = $POSTMATCH
          self.data = SafeYAML.load($1)
        end
      rescue SyntaxError => e
        Jekyll.logger.warn "YAML Exception reading #{File.join(base, name)}: #{e.message}"
      rescue Exception => e
        Jekyll.logger.warn "Error reading file #{File.join(base, name)}: #{e.message}"
      end

      self.data ||= {}

      unless self.data.is_a?(Hash)
        Jekyll.logger.abort_with "Fatal:", "Invalid YAML front matter in #{File.join(base, name)}"
      end

      self.data
    end

    def transform
      converters.reduce(content) do |output, converter|
        begin
          converter.convert output
        rescue => e
          Jekyll.logger.error "Conversion error:", "#{converter.class} encountered an error while converting '#{path}':"
          Jekyll.logger.error("", e.to_s)
          raise e
        end
      end
    end

    def output_ext
      if converters.all? { |c| c.is_a?(Jekyll::Converters::Identity) }
        ext
      else
        converters.map { |c|
          c.output_ext(ext) unless c.is_a?(Jekyll::Converters::Identity)
        }.compact.last
      end
    end

    def converters
      @converters ||= site.converters.select { |c| c.matches(ext) }.sort
    end

    def render_liquid(content, payload, info, path)
      site.liquid_renderer.file(path).parse(content).render(payload, info)
    rescue Tags::IncludeTagError => e
      Jekyll.logger.error "Liquid Exception:", "#{e.message} in #{e.path}, included in #{path || self.path}"
      raise e
    rescue Exception => e
      Jekyll.logger.error "Liquid Exception:", "#{e.message} in #{path || self.path}"
      raise e
    end

    def to_liquid(attrs = nil)
      further_data = Hash[(attrs || self.class::ATTRIBUTES_FOR_LIQUID).map { |attribute|
        #nodyna <send-2951> <SD COMPLEX (array)>
        [attribute, send(attribute)]
      }]

      defaults = site.frontmatter_defaults.all(relative_path, type)
      Utils.deep_merge_hashes defaults, Utils.deep_merge_hashes(data, further_data)
    end

    def type
      if is_a?(Draft)
        :drafts
      elsif is_a?(Post)
        :posts
      elsif is_a?(Page)
        :pages
      end
    end

    def asset_file?
      sass_file? || coffeescript_file?
    end

    def sass_file?
      %w[.sass .scss].include?(ext)
    end

    def coffeescript_file?
      '.coffee'.eql?(ext)
    end

    def render_with_liquid?
      true
    end

    def place_in_layout?
      !asset_file?
    end

    def invalid_layout?(layout)
      !data["layout"].nil? && layout.nil? && !(self.is_a? Jekyll::Excerpt)
    end

    def render_all_layouts(layouts, payload, info)
      layout = layouts[data["layout"]]

      Jekyll.logger.warn("Build Warning:", "Layout '#{data["layout"]}' requested in #{path} does not exist.") if invalid_layout? layout

      used = Set.new([layout])

      while layout
        payload = Utils.deep_merge_hashes(payload, {"content" => output, "page" => layout.data})

        self.output = render_liquid(layout.content,
                                         payload,
                                         info,
                                         File.join(site.config['layouts'], layout.name))

        site.regenerator.add_dependency(
          site.in_source_dir(path),
          site.in_source_dir(layout.path)
        )

        if layout = layouts[layout.data["layout"]]
          if used.include?(layout)
            layout = nil # avoid recursive chain
          else
            used << layout
          end
        end
      end
    end

    def do_layout(payload, layouts)
      Jekyll::Hooks.trigger self, :pre_render, payload
      info = { :filters => [Jekyll::Filters], :registers => { :site => site, :page => payload['page'] } }

      payload["highlighter_prefix"] = converters.first.highlighter_prefix
      payload["highlighter_suffix"] = converters.first.highlighter_suffix

      self.content = render_liquid(content, payload, info, path) if render_with_liquid?
      self.content = transform

      self.output = content

      render_all_layouts(layouts, payload, info) if place_in_layout?
      Jekyll::Hooks.trigger self, :post_render
    end

    def write(dest)
      path = destination(dest)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'wb') do |f|
        f.write(output)
      end
      Jekyll::Hooks.trigger self, :post_write
    end

    def [](property)
      if self.class::ATTRIBUTES_FOR_LIQUID.include?(property)
        #nodyna <send-2952> <SD COMPLEX (change-prone variables)>
        send(property)
      else
        data[property]
      end
    end
  end
end
