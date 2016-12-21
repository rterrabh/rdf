# == Issuable concern
#
# Contains common functionality shared between Issues and MergeRequests
#
# Used by Issue, MergeRequest
#
module Issuable
  extend ActiveSupport::Concern
  include Mentionable
  include Participable

  included do
    belongs_to :author, class_name: "User"
    belongs_to :assignee, class_name: "User"
    belongs_to :updated_by, class_name: "User"
    belongs_to :milestone
    has_many :notes, as: :noteable, dependent: :destroy
    has_many :label_links, as: :target, dependent: :destroy
    has_many :labels, through: :label_links
    has_many :subscriptions, dependent: :destroy, as: :subscribable

    validates :author, presence: true
    validates :title, presence: true, length: { within: 0..255 }

    scope :authored, ->(user) { where(author_id: user) }
    scope :assigned_to, ->(u) { where(assignee_id: u.id)}
    scope :recent, -> { order("created_at DESC") }
    scope :assigned, -> { where("assignee_id IS NOT NULL") }
    scope :unassigned, -> { where("assignee_id IS NULL") }
    scope :of_projects, ->(ids) { where(project_id: ids) }
    scope :opened, -> { with_state(:opened, :reopened) }
    scope :only_opened, -> { with_state(:opened) }
    scope :only_reopened, -> { with_state(:reopened) }
    scope :closed, -> { with_state(:closed) }
    scope :order_milestone_due_desc, -> { joins(:milestone).reorder('milestones.due_date DESC, milestones.id DESC') }
    scope :order_milestone_due_asc, -> { joins(:milestone).reorder('milestones.due_date ASC, milestones.id ASC') }

    delegate :name,
             :email,
             to: :author,
             prefix: true

    delegate :name,
             :email,
             to: :assignee,
             allow_nil: true,
             prefix: true

    attr_mentionable :title, :description
    participant :author, :assignee, :notes, :mentioned_users
  end

  module ClassMethods
    def search(query)
      where("LOWER(title) like :query", query: "%#{query.downcase}%")
    end

    def full_search(query)
      where("LOWER(title) like :query OR LOWER(description) like :query", query: "%#{query.downcase}%")
    end

    def sort(method)
      case method.to_s
      when 'milestone_due_asc' then order_milestone_due_asc
      when 'milestone_due_desc' then order_milestone_due_desc
      else
        order_by(method)
      end
    end
  end

  def today?
    Date.today == created_at.to_date
  end

  def new?
    today? && created_at == updated_at
  end

  def is_assigned?
    !!assignee_id
  end

  def is_being_reassigned?
    assignee_id_changed?
  end

  #
  # Votes
  #

  # Return the number of -1 comments (downvotes)
  def downvotes
    filter_superceded_votes(notes.select(&:downvote?), notes).size
  end

  def downvotes_in_percent
    if votes_count.zero?
      0
    else
      100.0 - upvotes_in_percent
    end
  end

  # Return the number of +1 comments (upvotes)
  def upvotes
    filter_superceded_votes(notes.select(&:upvote?), notes).size
  end

  def upvotes_in_percent
    if votes_count.zero?
      0
    else
      100.0 / votes_count * upvotes
    end
  end

  # Return the total number of votes
  def votes_count
    upvotes + downvotes
  end

  def subscribed?(user)
    subscription = subscriptions.find_by_user_id(user.id)

    if subscription
      return subscription.subscribed
    end

    participants(user).include?(user)
  end

  def toggle_subscription(user)
    subscriptions.
      find_or_initialize_by(user_id: user.id).
      update(subscribed: !subscribed?(user))
  end

  def to_hook_data(user)
    {
      object_kind: self.class.name.underscore,
      user: user.hook_attrs,
      object_attributes: hook_attrs
    }
  end

  def label_names
    labels.order('title ASC').pluck(:title)
  end

  def remove_labels
    labels.delete_all
  end

  def add_labels_by_names(label_names)
    label_names.each do |label_name|
      label = project.labels.create_with(color: Label::DEFAULT_COLOR).
        find_or_create_by(title: label_name.strip)
      self.labels << label
    end
  end

  # Convert this Issuable class name to a format usable by Ability definitions
  #
  # Examples:
  #
  #   issuable.class           # => MergeRequest
  #   issuable.to_ability_name # => "merge_request"
  def to_ability_name
    self.class.to_s.underscore
  end

  private

  def filter_superceded_votes(votes, notes)
    filteredvotes = [] + votes

    votes.each do |vote|
      if vote.superceded?(notes)
        filteredvotes.delete(vote)
      end
    end

    filteredvotes
  end
end
