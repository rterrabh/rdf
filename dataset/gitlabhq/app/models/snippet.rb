# == Schema Information
#
# Table name: snippets
#
#  id               :integer          not null, primary key
#  title            :string(255)
#  content          :text
#  author_id        :integer          not null
#  project_id       :integer
#  created_at       :datetime
#  updated_at       :datetime
#  file_name        :string(255)
#  expires_at       :datetime
#  type             :string(255)
#  visibility_level :integer          default(0), not null
#

class Snippet < ActiveRecord::Base
  include Gitlab::VisibilityLevel
  include Linguist::BlobHelper
  include Participable
  include Referable
  include Sortable

  default_value_for :visibility_level, Snippet::PRIVATE

  belongs_to :author, class_name: 'User'
  belongs_to :project

  has_many :notes, as: :noteable, dependent: :destroy

  delegate :name, :email, to: :author, prefix: true, allow_nil: true

  validates :author, presence: true
  validates :title, presence: true, length: { within: 0..255 }
  validates :file_name,
    length: { within: 0..255 },
    format: { with: Gitlab::Regex.file_name_regex,
              message: Gitlab::Regex.file_name_regex_message }
  validates :content, presence: true
  validates :visibility_level, inclusion: { in: Gitlab::VisibilityLevel.values }

  # Scopes
  scope :are_internal,  -> { where(visibility_level: Snippet::INTERNAL) }
  scope :are_private, -> { where(visibility_level: Snippet::PRIVATE) }
  scope :are_public, -> { where(visibility_level: Snippet::PUBLIC) }
  scope :public_and_internal, -> { where(visibility_level: [Snippet::PUBLIC, Snippet::INTERNAL]) }
  scope :fresh,   -> { order("created_at DESC") }
  scope :expired, -> { where(["expires_at IS NOT NULL AND expires_at < ?", Time.current]) }
  scope :non_expired, -> { where(["expires_at IS NULL OR expires_at > ?", Time.current]) }

  participant :author, :notes

  def self.reference_prefix
    '$'
  end

  # Pattern used to extract `$123` snippet references from text
  #
  # This pattern supports cross-project references.
  def self.reference_pattern
    %r{
      (#{Project.reference_pattern})?
      #{Regexp.escape(reference_prefix)}(?<snippet>\d+)
    }x
  end

  def to_reference(from_project = nil)
    reference = "#{self.class.reference_prefix}#{id}"

    if cross_project_reference?(from_project)
      reference = project.to_reference + reference
    end

    reference
  end

  def self.content_types
    [
      ".rb", ".py", ".pl", ".scala", ".c", ".cpp", ".java",
      ".haml", ".html", ".sass", ".scss", ".xml", ".php", ".erb",
      ".js", ".sh", ".coffee", ".yml", ".md"
    ]
  end

  def data
    content
  end

  def hook_attrs
    attributes
  end

  def size
    0
  end

  def name
    file_name
  end

  def sanitized_file_name
    file_name.gsub(/[^a-zA-Z0-9_\-\.]+/, '')
  end

  def mode
    nil
  end

  def expired?
    expires_at && expires_at < Time.current
  end

  def visibility_level_field
    visibility_level
  end

  class << self
    def search(query)
      where('(title LIKE :query OR file_name LIKE :query)', query: "%#{query}%")
    end

    def search_code(query)
      where('(content LIKE :query)', query: "%#{query}%")
    end

    def accessible_to(user)
      where('visibility_level IN (?) OR author_id = ?', [Snippet::INTERNAL, Snippet::PUBLIC], user)
    end
  end
end
