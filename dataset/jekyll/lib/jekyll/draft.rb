module Jekyll

  class Draft < Post

    MATCHER = /^(.*)(\.[^.]+)$/

    def self.valid?(name)
      name =~ MATCHER
    end

    def containing_dir(dir)
      site.in_source_dir(dir, '_drafts')
    end

    def relative_path
      File.join(@dir, '_drafts', @name)
    end

    def process(name)
      m, slug, ext = *name.match(MATCHER)
      self.date = File.mtime(File.join(@base, name))
      self.slug = slug
      self.ext = ext
    end

  end

end
