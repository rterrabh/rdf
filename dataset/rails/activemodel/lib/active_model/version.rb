require_relative 'gem_version'

module ActiveModel
  def self.version
    gem_version
  end
end
