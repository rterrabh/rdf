require_relative 'gem_version'

module Rails
  def self.version
    VERSION::STRING
  end
end
