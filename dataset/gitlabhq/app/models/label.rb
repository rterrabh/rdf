
class Label < ActiveRecord::Base
  include Referable

  DEFAULT_COLOR = '#428BCA'

  default_value_for :color, DEFAULT_COLOR

  belongs_to :project
  has_many :label_links, dependent: :destroy
  has_many :issues, through: :label_links, source: :target, source_type: 'Issue'

  validates :color,
            format: { with: /\A#[0-9A-Fa-f]{6}\Z/ },
            allow_blank: false
  validates :project, presence: true

  validates :title,
            presence: true,
            format: { with: /\A[^&\?,]+\z/ },
            uniqueness: { scope: :project_id }

  default_scope { order(title: :asc) }

  alias_attribute :name, :title

  def self.reference_prefix
    '~'
  end

  def self.reference_pattern
    %r{
      (?:
        (?<label_id>\d+) | # Integer-based label ID, or
        (?<label_name>
          [A-Za-z0-9_-]+ | # String-based single-word label title, or
          "[^&\?,]+"       # String-based multi-word label surrounded in quotes
        )
      )
    }x
  end

  def to_reference(format = :id)
    if format == :name && !name.include?('"')
      %(#{self.class.reference_prefix}"#{name}")
    else
      "#{self.class.reference_prefix}#{id}"
    end
  end

  def open_issues_count
    issues.opened.count
  end
end
