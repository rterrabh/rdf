require_relative 'gem_version'

module ActiveSupport
  def self.version
    gem_version
  end
end
