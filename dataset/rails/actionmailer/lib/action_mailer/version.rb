require_relative 'gem_version'

module ActionMailer
  def self.version
    gem_version
  end
end
