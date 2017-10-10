
module Jekyll

  class Site
    def read_posts(dir)
      base = File.join(self.source, dir, '_posts')
      return unless File.exists?(base)
      entries = Dir.chdir(base) { filter_entries(Dir['**/*']) }

      entries.each do |f|
        if Post.valid?(f)
          post = Post.new(self, self.source, dir, f)

          if ENV.has_key?('OCTOPRESS_ENV') && ENV['OCTOPRESS_ENV'] == 'preview' && post.data.has_key?('published') && post.data['published'] == false
            post.published = true
            File.open(".preview-mode", "w") {}
          end

          if post.published && (self.future || post.date <= self.time)
            self.posts << post
            post.categories.each { |c| self.categories[c] << post }
            post.tags.each { |c| self.tags[c] << post }
          end
        end
      end

      self.posts.sort!

      self.posts = self.posts[-limit_posts, limit_posts] if limit_posts
    end
  end
end
