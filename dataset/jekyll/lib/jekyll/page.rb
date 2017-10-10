module Jekyll
  class Page
    include Convertible

    attr_writer :dir
    attr_accessor :site, :pager
    attr_accessor :name, :ext, :basename
    attr_accessor :data, :content, :output

    ATTRIBUTES_FOR_LIQUID = %w[
      content
      dir
      name
      path
      url
    ]

    def initialize(site, base, dir, name)
      @site = site
      @base = base
      @dir  = dir
      @name = name


      process(name)
      read_yaml(File.join(base, dir), name)

      data.default_proc = proc do |hash, key|
        site.frontmatter_defaults.find(File.join(dir, name), type, key)
      end

      Jekyll::Hooks.trigger self, :post_init
    end

    def dir
      url[-1, 1] == '/' ? url : File.dirname(url)
    end

    def permalink
      return nil if data.nil? || data['permalink'].nil?
      data['permalink']
    end

    def template
      if !html?
        "/:path/:basename:output_ext"
      elsif index?
        "/:path/"
      else
        Utils.add_permalink_suffix("/:path/:basename", site.permalink_style)
      end
    end

    def url
      @url ||= URL.new({
        :template => template,
        :placeholders => url_placeholders,
        :permalink => permalink
      }).to_s
    end

    def url_placeholders
      {
        :path       => @dir,
        :basename   => basename,
        :output_ext => output_ext
      }
    end

    def process(name)
      self.ext = File.extname(name)
      self.basename = name[0 .. -ext.length - 1]
    end

    def render(layouts, site_payload)
      payload = Utils.deep_merge_hashes({
        "page" => to_liquid,
        'paginator' => pager.to_liquid
      }, site_payload)

      do_layout(payload, layouts)
    end

    def path
      data.fetch('path') { relative_path.sub(/\A\//, '') }
    end

    def relative_path
      File.join(*[@dir, @name].map(&:to_s).reject(&:empty?))
    end

    def destination(dest)
      path = site.in_dest_dir(dest, URL.unescape_path(url))
      path = File.join(path, "index.html") if url.end_with?("/")
      path << output_ext unless path.end_with?(output_ext)
      path
    end

    def inspect
      "#<Jekyll:Page @name=#{name.inspect}>"
    end

    def html?
      output_ext == '.html'
    end

    def index?
      basename == 'index'
    end
  end
end
