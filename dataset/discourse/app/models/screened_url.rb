require_dependency 'screening_model'


class ScreenedUrl < ActiveRecord::Base

  include ScreeningModel

  default_action :do_nothing

  before_validation :normalize

  validates :url, presence: true, uniqueness: true
  validates :domain, presence: true

  def normalize
    self.url = ScreenedUrl.normalize_url(self.url) if self.url
    self.domain = self.domain.downcase.sub(/^www\./, '') if self.domain
  end

  def self.watch(url, domain, opts={})
    find_match(url) || create(opts.slice(:action_type, :ip_address).merge(url: url, domain: domain))
  end

  def self.find_match(url)
    find_by_url normalize_url(url)
  end

  def self.normalize_url(url)
    normalized = url.gsub(/http(s?):\/\//i, '')
    normalized.gsub!(/(\/)+$/, '') # trim trailing slashes
    normalized.gsub!(/^([^\/]+)(?:\/)?/) { |m| m.downcase } # downcase the domain part of the url
    normalized
  end
end

