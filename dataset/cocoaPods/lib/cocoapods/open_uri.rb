require 'open-uri'

module OpenURI
  def self.redirectable?(uri1, uri2)
    uri1.scheme.downcase == uri2.scheme.downcase ||
      (/\A(?:http|ftp)\z/i =~ uri1.scheme && /\A(?:https?|ftp)\z/i =~ uri2.scheme)
  end
end
