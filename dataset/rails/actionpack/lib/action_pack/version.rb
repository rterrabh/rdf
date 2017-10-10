require_relative 'gem_version'

module ActionPack
  def self.version
    gem_version
  end
end
