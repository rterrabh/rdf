require 'csv'

module Jekyll
  class Site
    attr_reader   :source, :dest, :config
    attr_accessor :layouts, :posts, :pages, :static_files, :drafts,
                  :exclude, :include, :lsi, :highlighter, :permalink_style,
                  :time, :future, :unpublished, :safe, :plugins, :limit_posts,
                  :show_drafts, :keep_files, :baseurl, :data, :file_read_opts,
                  :gems, :plugin_manager

    attr_accessor :converters, :generators, :reader
    attr_reader   :regenerator, :liquid_renderer

    def initialize(config)
      @config = config.clone

      %w[safe lsi highlighter baseurl exclude include future unpublished
        show_drafts limit_posts keep_files gems].each do |opt|
        #nodyna <send-2947> <not yet classified>
        self.send("#{opt}=", config[opt])
      end

      @source              = File.expand_path(config['source']).freeze
      @dest                = File.expand_path(config['destination']).freeze

      @reader = Jekyll::Reader.new(self)

      @regenerator = Regenerator.new(self)

      @liquid_renderer = LiquidRenderer.new(self)

      self.plugin_manager = Jekyll::PluginManager.new(self)
      self.plugins        = plugin_manager.plugins_path

      self.file_read_opts = {}
      self.file_read_opts[:encoding] = config['encoding'] if config['encoding']

      self.permalink_style = config['permalink'].to_sym

      Jekyll.sites << self

      reset
      setup
    end

    def process
      reset
      read
      generate
      render
      cleanup
      write
      print_stats
    end

    def print_stats
      if @config['profile']
        puts @liquid_renderer.stats_table
      end
    end

    def reset
      self.time = (config['time'] ? Utils.parse_date(config['time'].to_s, "Invalid time in _config.yml.") : Time.now)
      self.layouts = {}
      self.posts = []
      self.pages = []
      self.static_files = []
      self.data = {}
      @collections = nil
      @regenerator.clear_cache
      @liquid_renderer.reset

      if limit_posts < 0
        raise ArgumentError, "limit_posts must be a non-negative number"
      end

      Jekyll::Hooks.trigger self, :after_reset
    end

    def setup
      ensure_not_in_dest

      plugin_manager.conscientious_require

      self.converters = instantiate_subclasses(Jekyll::Converter)
      self.generators = instantiate_subclasses(Jekyll::Generator)
    end

    def ensure_not_in_dest
      dest_pathname = Pathname.new(dest)
      Pathname.new(source).ascend do |path|
        if path == dest_pathname
          raise Errors::FatalException.new "Destination directory cannot be or contain the Source directory."
        end
      end
    end

    def collections
      @collections ||= Hash[collection_names.map { |coll| [coll, Jekyll::Collection.new(self, coll)] } ]
    end

    def collection_names
      case config['collections']
      when Hash
        config['collections'].keys
      when Array
        config['collections']
      when nil
        []
      else
        raise ArgumentError, "Your `collections` key must be a hash or an array."
      end
    end

    def read
      reader.read
      limit_posts!
      Jekyll::Hooks.trigger self, :post_read
    end

    def generate
      generators.each do |generator|
        generator.generate(self)
      end
    end

    def render
      relative_permalinks_are_deprecated

      payload = site_payload

      Jekyll::Hooks.trigger self, :pre_render, payload

      collections.each do |label, collection|
        collection.docs.each do |document|
          if regenerator.regenerate?(document)
            document.output = Jekyll::Renderer.new(self, document, payload).run
            Jekyll::Hooks.trigger document, :post_render
          end
        end
      end

      [posts, pages].flatten.each do |page_or_post|
        if regenerator.regenerate?(page_or_post)
          page_or_post.render(layouts, payload)
        end
      end
    rescue Errno::ENOENT
    end

    def cleanup
      site_cleaner.cleanup!
    end

    def write
      each_site_file { |item|
        item.write(dest) if regenerator.regenerate?(item)
      }
      regenerator.write_metadata
      Jekyll::Hooks.trigger self, :post_write
    end

    def post_attr_hash(post_attr)
      hash = Hash.new { |h, key| h[key] = [] }
      #nodyna <send-2948> <not yet classified>
      posts.each { |p| p.send(post_attr.to_sym).each { |t| hash[t] << p } }
      hash.values.each { |posts| posts.sort!.reverse! }
      hash
    end

    def tags
      post_attr_hash('tags')
    end

    def categories
      post_attr_hash('categories')
    end

    def site_data
      config['data'] || data
    end

    def site_payload
      {
        "jekyll" => {
          "version" => Jekyll::VERSION,
          "environment" => Jekyll.env
        },
        "site"   => Utils.deep_merge_hashes(config,
          Utils.deep_merge_hashes(Hash[collections.map{|label, coll| [label, coll.docs]}], {
            "time"         => time,
            "posts"        => posts.sort { |a, b| b <=> a },
            "pages"        => pages,
            "static_files" => static_files,
            "html_pages"   => pages.select { |page| page.html? || page.url.end_with?("/") },
            "categories"   => post_attr_hash('categories'),
            "tags"         => post_attr_hash('tags'),
            "collections"  => collections.values.map(&:to_liquid),
            "documents"    => documents,
            "data"         => site_data
        }))
      }
    end

    def find_converter_instance(klass)
      converters.find { |c| c.class == klass } || proc { raise "No converter for #{klass}" }.call
    end

    def instantiate_subclasses(klass)
      klass.descendants.select do |c|
        !safe || c.safe
      end.sort.map do |c|
        c.new(config)
      end
    end

    def relative_permalinks_are_deprecated
      if config['relative_permalinks']
        Jekyll.logger.abort_with "Since v3.0, permalinks for pages" +
                                " in subfolders must be relative to the" +
                                " site source directory, not the parent" +
                                " directory. Check http://jekyllrb.com/docs/upgrading/"+
                                " for more info."
      end
    end

    def docs_to_write
      documents.select(&:write?)
    end

    def documents
      collections.reduce(Set.new) do |docs, (_, collection)|
        docs + collection.docs + collection.files
      end.to_a
    end

    def each_site_file
      %w(posts pages static_files docs_to_write).each do |type|
        #nodyna <send-2949> <not yet classified>
        send(type).each do |item|
          yield item
        end
      end
    end

    def frontmatter_defaults
      @frontmatter_defaults ||= FrontmatterDefaults.new(self)
    end

    def full_rebuild?(override = {})
      override['full_rebuild'] || config['full_rebuild']
    end

    def publisher
      @publisher ||= Publisher.new(self)
    end

    def in_source_dir(*paths)
      paths.reduce(source) do |base, path|
        Jekyll.sanitized_path(base, path)
      end
    end

    def in_dest_dir(*paths)
      paths.reduce(dest) do |base, path|
        Jekyll.sanitized_path(base, path)
      end
    end

    private

    def limit_posts!
      if limit_posts > 0
        limit = posts.length < limit_posts ? posts.length : limit_posts
        self.posts = posts[-limit, limit]
      end
    end

    def site_cleaner
      @site_cleaner ||= Cleaner.new(self)
    end
  end
end
