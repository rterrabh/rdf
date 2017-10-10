
require "open-uri"

module OpenURI
  class <<self
    alias_method :open_uri_original, :open_uri
    alias_method :redirectable_cautious?, :redirectable?

    def redirectable?(uri1, uri2)
      case Thread.current[:__open_uri_redirections__]
      when :safe
        redirectable_safe? uri1, uri2
      when :all
        redirectable_all? uri1, uri2
      else
        redirectable_cautious? uri1, uri2
      end
    end

    def redirectable_safe?(uri1, uri2)
      redirectable_cautious?(uri1, uri2) || http_to_https?(uri1, uri2)
    end

    def redirectable_all?(uri1, uri2)
      redirectable_safe?(uri1, uri2) || https_to_http?(uri1, uri2)
    end
  end

  def self.open_uri(name, *rest, &block)
    Thread.current[:__open_uri_redirections__] = allow_redirections(rest)

    block2 = lambda do |io|
      Thread.current[:__open_uri_redirections__] = nil
      block[io]
    end

    begin
      open_uri_original name, *rest, &(block ? block2 : nil)
    ensure
      Thread.current[:__open_uri_redirections__] = nil
    end
  end

  private

  def self.allow_redirections(args)
    options = first_hash_argument(args)
    options.delete :allow_redirections if options
  end

  def self.first_hash_argument(arguments)
    arguments.select { |arg| arg.is_a? Hash }.first
  end

  def self.http_to_https?(uri1, uri2)
    schemes_from([uri1, uri2]) == %w(http https)
  end

  def self.https_to_http?(uri1, uri2)
    schemes_from([uri1, uri2]) == %w(https http)
  end

  def self.schemes_from(uris)
    uris.map { |u| u.scheme.downcase }
  end
end
