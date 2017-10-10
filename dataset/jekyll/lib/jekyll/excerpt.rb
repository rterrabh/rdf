require 'forwardable'

module Jekyll
  class Excerpt
    include Convertible
    extend Forwardable

    attr_accessor :post
    attr_accessor :content, :output, :ext

    def_delegator :@post, :site, :site
    def_delegator :@post, :name, :name
    def_delegator :@post, :ext,  :ext

    def initialize(post)
      self.post = post
      self.content = extract_excerpt(post.content)
    end

    def to_liquid
      post.to_liquid(post.class::EXCERPT_ATTRIBUTES_FOR_LIQUID)
    end

    def data
      @data ||= post.data.dup
      @data.delete("layout")
      @data
    end

    def path
      File.join(post.path, "#excerpt")
    end

    def include?(something)
      (output && output.include?(something)) || content.include?(something)
    end

    def id
      File.join(post.dir, post.slug, "#excerpt")
    end

    def to_s
      output || content
    end

    def inspect
      "<Excerpt: #{self.id}>"
    end

    protected

    def extract_excerpt(post_content)
      head, _, tail = post_content.to_s.partition(post.excerpt_separator)

      "" << head << "\n\n" << tail.scan(/^\[[^\]]+\]:.+$/).join("\n")
    end
  end
end
