
module Jekyll
  class Document
    include Comparable

    attr_reader :path, :site, :extname, :output_ext, :content, :output, :collection

    YAML_FRONT_MATTER_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m

    def initialize(path, relations)
      @site = relations[:site]
      @path = path
      @extname = File.extname(path)
      @output_ext = Jekyll::Renderer.new(site, self).output_ext
      @collection = relations[:collection]
      @has_yaml_header = nil
    end

    def output=(output)
      @to_liquid = nil
      @output = output
    end

    def content=(content)
      @to_liquid = nil
      @content = content
    end

    def data
      @data ||= Hash.new
    end

    def relative_path
      @relative_path ||= Pathname.new(path).relative_path_from(Pathname.new(site.source)).to_s
    end

    def basename_without_ext
      @basename_without_ext ||= File.basename(path, '.*')
    end

    def basename
      @basename ||= File.basename(path)
    end

    def cleaned_relative_path
      @cleaned_relative_path ||=
        relative_path[0 .. -extname.length - 1].sub(collection.relative_directory, "")
    end

    def yaml_file?
      %w[.yaml .yml].include?(extname)
    end

    def asset_file?
      sass_file? || coffeescript_file?
    end

    def sass_file?
      %w[.sass .scss].include?(extname)
    end

    def coffeescript_file?
      '.coffee'.eql?(extname)
    end

    def render_with_liquid?
      !(coffeescript_file? || yaml_file?)
    end

    def place_in_layout?
      !(asset_file? || yaml_file?)
    end

    def url_template
      collection.url_template
    end

    def url_placeholders
      {
        collection: collection.label,
        path:       cleaned_relative_path,
        output_ext: output_ext,
        name:       Utils.slugify(basename_without_ext),
        title:      Utils.slugify(data['slug']) || Utils.slugify(basename_without_ext)
      }
    end

    def permalink
      data && data.is_a?(Hash) && data['permalink']
    end

    def url
      @url = URL.new({
        template:     url_template,
        placeholders: url_placeholders,
        permalink:    permalink
      }).to_s
    end

    def destination(base_directory)
      dest = site.in_dest_dir(base_directory)
      path = site.in_dest_dir(dest, URL.unescape_path(url))
      path = File.join(path, "index.html") if url.end_with?("/")
      path << output_ext unless path.end_with?(output_ext)
      path
    end

    def write(dest)
      path = destination(dest)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'wb') do |f|
        f.write(output)
      end

      Jekyll::Hooks.trigger self, :post_write
    end

    def merged_file_read_opts(opts)
      site ? site.file_read_opts.merge(opts) : opts
    end

    def published?
      !(data.key?('published') && data['published'] == false)
    end

    def read(opts = {})
      @to_liquid = nil

      if yaml_file?
        @data = SafeYAML.load_file(path)
      else
        begin
          defaults = @site.frontmatter_defaults.all(url, collection.label.to_sym)
          unless defaults.empty?
            @data = defaults
          end
          self.content = File.read(path, merged_file_read_opts(opts))
          if content =~ YAML_FRONT_MATTER_REGEXP
            self.content = $POSTMATCH
            data_file = SafeYAML.load($1)
            unless data_file.nil?
              @data = Utils.deep_merge_hashes(defaults, data_file)
            end
          end
        rescue SyntaxError => e
          puts "YAML Exception reading #{path}: #{e.message}"
        rescue Exception => e
          puts "Error reading file #{path}: #{e.message}"
        end
      end
    end

    def to_liquid
      @to_liquid ||= if data.is_a?(Hash)
        Utils.deep_merge_hashes data, {
          "output"        => output,
          "content"       => content,
          "relative_path" => relative_path,
          "path"          => relative_path,
          "url"           => url,
          "collection"    => collection.label
        }
      else
        data
      end
    end

    def inspect
      "#<Jekyll::Document #{relative_path} collection=#{collection.label}>"
    end

    def to_s
      content || ''
    end

    def <=>(anotherDocument)
      path <=> anotherDocument.path
    end

    def write?
      collection && collection.write?
    end
  end
end
