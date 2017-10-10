module Jekyll

  class PostFilter < Plugin

    def pre_render(post)
    end

    def post_render(post)
    end

    def post_write(post)
    end
  end

  class Site

    attr_accessor :post_filters

    def load_post_filters
      self.post_filters = Jekyll::PostFilter.subclasses.select do |c|
        !self.safe || c.safe
      end.map do |c|
        c.new(self.config)
      end
    end
  end

  class Post

    alias_method :old_write, :write

    def write(dest)
      old_write(dest)
      post_write if respond_to?(:post_write)
    end
  end

  class Page

    alias_method :old_write, :write

    def write(dest)
      old_write(dest)
      post_write if respond_to?(:post_write)
    end
  end

  module Convertible

    def is_post?
      self.class.to_s == 'Jekyll::Post'
    end

    def is_page?
      self.class.to_s == 'Jekyll::Page'
    end

    def is_filterable?
      is_post? or is_page?
    end

    def pre_render
      self.site.load_post_filters unless self.site.post_filters

      if self.site.post_filters and is_filterable?
        self.site.post_filters.each do |filter|
          filter.pre_render(self)
        end
      end
    end

    def post_render
      if self.site.post_filters and is_filterable?
        self.site.post_filters.each do |filter|
          filter.post_render(self)
        end
      end
    end

    def post_write
      if self.site.post_filters and is_filterable?
        self.site.post_filters.each do |filter|
          filter.post_write(self)
        end
      end
    end

    alias_method :old_transform, :transform

    def transform
      old_transform
      post_render if respond_to?(:post_render)
    end

    alias_method :old_do_layout, :do_layout

    def do_layout(payload, layouts)
      pre_render if respond_to?(:pre_render)
      old_do_layout(payload, layouts)
    end

    def full_url
      self.site.config['url'] + self.url
    end
  end
end
