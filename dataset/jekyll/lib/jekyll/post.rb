module Jekyll
  class Post
    include Comparable
    include Convertible

    MATCHER = /^(.+\/)*(\d+-\d+-\d+)-(.*)(\.[^.]+)$/

    EXCERPT_ATTRIBUTES_FOR_LIQUID = %w[
      title
      url
      dir
      date
      id
      categories
      next
      previous
      tags
      path
    ]

    ATTRIBUTES_FOR_LIQUID = EXCERPT_ATTRIBUTES_FOR_LIQUID + %w[
      content
      excerpt
      excerpt_separator
      draft?
    ]

    def self.valid?(name)
      name =~ MATCHER
    end

    attr_accessor :site
    attr_accessor :data, :extracted_excerpt, :content, :output, :ext
    attr_accessor :date, :slug, :tags, :categories

    attr_reader :name

    def initialize(site, source, dir, name)
      @site = site
      @dir = dir
      @base = containing_dir(dir)
      @name = name

      self.categories = dir.split('/').reject { |x| x.empty? }
      process(name)
      read_yaml(@base, name)

      data.default_proc = proc do |hash, key|
        site.frontmatter_defaults.find(relative_path, type, key)
      end

      if data.key?('date')
        self.date = Utils.parse_date(data["date"].to_s, "Post '#{relative_path}' does not have a valid date in the YAML front matter.")
      end

      populate_categories
      populate_tags

      Jekyll::Hooks.trigger self, :post_init
    end

    def published?
      if data.key?('published') && data['published'] == false
        false
      else
        true
      end
    end

    def populate_categories
      categories_from_data = Utils.pluralized_array_from_hash(data, 'category', 'categories')
      self.categories = (
        Array(categories) + categories_from_data
      ).map { |c| c.to_s }.flatten.uniq
    end

    def populate_tags
      self.tags = Utils.pluralized_array_from_hash(data, "tag", "tags").flatten
    end

    def containing_dir(dir)
      site.in_source_dir(dir, '_posts')
    end

    def read_yaml(base, name)
      super(base, name)
      self.extracted_excerpt = extract_excerpt
    end

    def excerpt
      data.fetch('excerpt') { extracted_excerpt.to_s }
    end

    def title
      data.fetch('title') { titleized_slug }
    end

    def excerpt_separator
      (data['excerpt_separator'] || site.config['excerpt_separator']).to_s
    end

    def titleized_slug
      slug.split('-').select {|w| w.capitalize! || w }.join(' ')
    end

    def path
      data.fetch('path') { relative_path.sub(/\A\//, '') }
    end

    def relative_path
      File.join(*[@dir, "_posts", @name].map(&:to_s).reject(&:empty?))
    end

    def <=>(other)
      cmp = self.date <=> other.date
      if 0 == cmp
       cmp = self.slug <=> other.slug
      end
      return cmp
    end

    def process(name)
      m, cats, date, slug, ext = *name.match(MATCHER)
      self.date = Utils.parse_date(date, "Post '#{relative_path}' does not have a valid date in the filename.")
      self.slug = slug
      self.ext = ext
    end

    def dir
      File.dirname(url)
    end

    def permalink
      data && data['permalink']
    end

    def template
      case site.permalink_style
      when :pretty
        "/:categories/:year/:month/:day/:title/"
      when :none
        "/:categories/:title.html"
      when :date
        "/:categories/:year/:month/:day/:title.html"
      when :ordinal
        "/:categories/:year/:y_day/:title.html"
      else
        site.permalink_style.to_s
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
        :year        => date.strftime("%Y"),
        :month       => date.strftime("%m"),
        :day         => date.strftime("%d"),
        :title       => slug,
        :i_day       => date.strftime("%-d"),
        :i_month     => date.strftime("%-m"),
        :categories  => (categories || []).map { |c| c.to_s.downcase }.uniq.join('/'),
        :short_month => date.strftime("%b"),
        :short_year  => date.strftime("%y"),
        :y_day       => date.strftime("%j"),
        :output_ext  => output_ext
      }
    end

    def id
      File.join(dir, slug)
    end

    def related_posts(posts)
      Jekyll::RelatedPosts.new(self).build
    end

    def render(layouts, site_payload)
      payload = Utils.deep_merge_hashes({
        "site" => { "related_posts" => related_posts(site_payload["site"]["posts"]) },
        "page" => to_liquid(self.class::EXCERPT_ATTRIBUTES_FOR_LIQUID)
      }, site_payload)

      if generate_excerpt?
        extracted_excerpt.do_layout(payload, {})
      end

      do_layout(payload.merge({"page" => to_liquid}), layouts)
    end

    def destination(dest)
      path = site.in_dest_dir(dest, URL.unescape_path(url))
      path = File.join(path, "index.html") if self.url.end_with?("/")
      path << output_ext unless path.end_with?(output_ext)
      path
    end

    def inspect
      "<Post: #{id}>"
    end

    def next
      pos = site.posts.index {|post| post.equal?(self) }
      if pos && pos < site.posts.length - 1
        site.posts[pos + 1]
      else
        nil
      end
    end

    def previous
      pos = site.posts.index {|post| post.equal?(self) }
      if pos && pos > 0
        site.posts[pos - 1]
      else
        nil
      end
    end

    def draft?
      is_a?(Jekyll::Draft)
    end

    protected

    def extract_excerpt
      if generate_excerpt?
        Jekyll::Excerpt.new(self)
      else
        ""
      end
    end

    def generate_excerpt?
      !excerpt_separator.empty?
    end
  end
end
