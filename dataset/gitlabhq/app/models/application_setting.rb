
class ApplicationSetting < ActiveRecord::Base
  serialize :restricted_visibility_levels
  serialize :restricted_signup_domains, Array
  attr_accessor :restricted_signup_domains_raw

  validates :session_expire_delay,
    presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :home_page_url,
    allow_blank: true,
    format: { with: /\A#{URI.regexp(%w(http https))}\z/, message: "should be a valid url" },
    if: :home_page_url_column_exist

  validates :after_sign_out_path,
    allow_blank: true,
    format: { with: /\A#{URI.regexp(%w(http https))}\z/, message: "should be a valid url" }

  validates_each :restricted_visibility_levels do |record, attr, value|
    unless value.nil?
      value.each do |level|
        unless Gitlab::VisibilityLevel.options.has_value?(level)
          record.errors.add(attr, "'#{level}' is not a valid visibility level")
        end
      end
    end
  end

  def self.current
    ApplicationSetting.last
  end

  def self.create_from_defaults
    create(
      default_projects_limit: Settings.gitlab['default_projects_limit'],
      default_branch_protection: Settings.gitlab['default_branch_protection'],
      signup_enabled: Settings.gitlab['signup_enabled'],
      signin_enabled: Settings.gitlab['signin_enabled'],
      twitter_sharing_enabled: Settings.gitlab['twitter_sharing_enabled'],
      gravatar_enabled: Settings.gravatar['enabled'],
      sign_in_text: Settings.extra['sign_in_text'],
      restricted_visibility_levels: Settings.gitlab['restricted_visibility_levels'],
      max_attachment_size: Settings.gitlab['max_attachment_size'],
      session_expire_delay: Settings.gitlab['session_expire_delay'],
      default_project_visibility: Settings.gitlab.default_projects_features['visibility_level'],
      default_snippet_visibility: Settings.gitlab.default_projects_features['visibility_level'],
      restricted_signup_domains: Settings.gitlab['restricted_signup_domains']
    )
  end

  def home_page_url_column_exist
    ActiveRecord::Base.connection.column_exists?(:application_settings, :home_page_url)
  end

  def restricted_signup_domains_raw
    self.restricted_signup_domains.join("\n") unless self.restricted_signup_domains.nil?
  end

  def restricted_signup_domains_raw=(values)
    self.restricted_signup_domains = []
    self.restricted_signup_domains = values.split(
        /\s*[,;]\s*     # comma or semicolon, optionally surrounded by whitespace
        |               # or
        \s              # any whitespace character
        |               # or
        [\r\n]          # any number of newline characters
        /x)
    self.restricted_signup_domains.reject! { |d| d.empty? }
  end

end
