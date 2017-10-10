require_relative 'gem_version'

module ActiveRecord
  def self.version
    gem_version
  end
end
