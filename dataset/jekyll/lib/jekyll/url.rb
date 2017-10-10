require 'uri'

module Jekyll
  class URL

    def initialize(options)
      @template     = options[:template]
      @placeholders = options[:placeholders] || {}
      @permalink    = options[:permalink]

      if (@template || @permalink).nil?
        raise ArgumentError, "One of :template or :permalink must be supplied."
      end
    end

    def to_s
      sanitize_url(generated_permalink || generated_url)
    end

    def generated_permalink
      (@generated_permalink ||= generate_url(@permalink)) if @permalink
    end

    def generated_url
      @generated_url ||= generate_url(@template)
    end

    def generate_url(template)
      @placeholders.inject(template) do |result, token|
        break result if result.index(':').nil?
        if token.last.nil?
          result.gsub(/\/:#{token.first}/, '')
        else
          result.gsub(/:#{token.first}/, self.class.escape_path(token.last))
        end
      end
    end

    def sanitize_url(in_url)
      url = in_url \
        .gsub(/\/\//, '/') \
        .split('/').reject{ |part| part =~ /^\.+$/ }.join('/') \
        .gsub(/\A([^\/])/, '/\1')

      url << "/" if in_url.end_with?("/")

      url
    end

    def self.escape_path(path)
      URI.escape(path, /[^a-zA-Z\d\-._~!$&'()*+,;=:@\/]/).encode('utf-8')
    end

    def self.unescape_path(path)
      URI.unescape(path.encode('utf-8'))
    end
  end
end
