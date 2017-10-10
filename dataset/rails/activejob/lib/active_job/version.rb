require_relative 'gem_version'

module ActiveJob
  def self.version
    gem_version
  end
end
