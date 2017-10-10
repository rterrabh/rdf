require_relative 'gem_version'

module ActionView
  def self.version
    gem_version
  end
end
