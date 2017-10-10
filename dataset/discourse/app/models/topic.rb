require_dependency 'slug'
require_dependency 'avatar_lookup'
require_dependency 'topic_view'
require_dependency 'rate_limiter'
require_dependency 'text_sentinel'
require_dependency 'text_cleaner'
require_dependency 'archetype'

class Topic < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  include RateLimiter::OnCreateRecord
  include HasCustomFields
  include Trashable
  include LimitedEdit
  extend Forwardable

  def_delegator :featured_users, :user_ids, :featured_user_ids
  def_delegator :featured_users, :choose, :feature_topic_users

  def_delegator :notifier, :watch!, :notify_watch!
  def_delegator :notifier, :tracking!, :notify_tracking!
  def_delegator :notifier, :regular!, :notify_regular!
  def_delegator :notifier, :muted!, :notify_muted!
  def_delegator :notifier, :toggle_mute, :toggle_mute

  attr_accessor :allowed_user_ids

  def self.max_sort_order
    2**31 - 1
  end

  def featured_users
    @featured_users ||= TopicFeaturedUsers.new(self)
  end

  def trash!(trashed_by=nil)
    update_category_topic_count_by(-1) if deleted_at.nil?
    super(trashed_by)
    update_flagged_posts_count
  end

  def recover!
    update_category_topic_count_by(1) unless deleted_at.nil?
    super
    update_flagged_posts_count
  end

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validates :title, :if => Proc.new { |t| t.new_record? || t.title_changed? },
                    :presence => true,
                    :topic_title_length => true,
                    :quality_title => { :unless => :private_message? },
                    :unique_among  => { :unless => Proc.new { |t| (SiteSetting.allow_duplicate_topic_titles? || t.private_message?) },
                                        :message => :has_already_been_used,
                                        :allow_blank => true,
                                        :case_sensitive => false,
                                        :collection => Proc.new{ Topic.listable_topics } }

  validates :category_id,
            :presence => true,
            :exclusion => {
              :in => Proc.new{[SiteSetting.uncategorized_category_id]}
            },
            :if => Proc.new { |t|
                   (t.new_record? || t.category_id_changed?) &&
                   !SiteSetting.allow_uncategorized_topics &&
                   (t.archetype.nil? || t.archetype == Archetype.default) &&
                   (!t.user_id || !t.user.staff?)
            }


  before_validation do
    self.title = TextCleaner.clean_title(TextSentinel.title_sentinel(title).text) if errors[:title].empty?
  end

  belongs_to :category
  has_many :posts
  has_many :ordered_posts, -> { order(post_number: :asc) }, class_name: "Post"
  has_many :topic_allowed_users
  has_many :topic_allowed_groups

  has_many :allowed_group_users, through: :allowed_groups, source: :users
  has_many :allowed_groups, through: :topic_allowed_groups, source: :group
  has_many :allowed_users, through: :topic_allowed_users, source: :user
  has_many :queued_posts

  has_one :top_topic
  belongs_to :user
  belongs_to :last_poster, class_name: 'User', foreign_key: :last_post_user_id
  belongs_to :featured_user1, class_name: 'User', foreign_key: :featured_user1_id
  belongs_to :featured_user2, class_name: 'User', foreign_key: :featured_user2_id
  belongs_to :featured_user3, class_name: 'User', foreign_key: :featured_user3_id
  belongs_to :featured_user4, class_name: 'User', foreign_key: :featured_user4_id
  belongs_to :auto_close_user, class_name: 'User', foreign_key: :auto_close_user_id

  has_many :topic_users
  has_many :topic_links
  has_many :topic_invites
  has_many :invites, through: :topic_invites, source: :invite

  has_one :warning

  has_one :first_post, -> {where post_number: 1}, class_name: Post

  attr_accessor :user_data

  attr_accessor :posters  # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :participants
  attr_accessor :topic_list
  attr_accessor :meta_data
  attr_accessor :include_last_poster
  attr_accessor :import_mode # set to true to optimize creation and save for imports

  scope :topic_list_order, -> { order('topics.bumped_at desc') }

  scope :private_messages, -> { where(archetype: Archetype.private_message) }

  scope :listable_topics, -> { where('topics.archetype <> ?', [Archetype.private_message]) }

  scope :by_newest, -> { order('topics.created_at desc, topics.id desc') }

  scope :visible, -> { where(visible: true) }

  scope :created_since, lambda { |time_ago| where('topics.created_at > ?', time_ago) }

  scope :secured, lambda { |guardian=nil|
    ids = guardian.secure_category_ids if guardian

    condition = if ids.present?
      ["NOT c.read_restricted or c.id in (:cats)", cats: ids]
    else
      ["NOT c.read_restricted"]
    end

    where("category_id IS NULL OR category_id IN (
           SELECT c.id FROM categories c
           WHERE #{condition[0]})", condition[1])
  }

  attr_accessor :ignore_category_auto_close
  attr_accessor :skip_callbacks

  before_create do
    initialize_default_values
    inherit_auto_close_from_category
  end

  after_create do
    unless skip_callbacks
      changed_to_category(category)
      advance_draft_sequence
    end
  end

  before_save do
    unless skip_callbacks
      cancel_auto_close_job
      ensure_topic_has_a_category
    end
  end

  after_save do
    unless skip_callbacks
      schedule_auto_close_job
    end

    banner = "banner".freeze

    if archetype_was == banner || archetype == banner
      ApplicationController.banner_json_cache.clear
    end
  end

  def initialize_default_values
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
  end

  def inherit_auto_close_from_category
    if !@ignore_category_auto_close && self.category && self.category.auto_close_hours && self.auto_close_at.nil?
      self.auto_close_based_on_last_post = self.category.auto_close_based_on_last_post
      set_auto_close(self.category.auto_close_hours)
    end
  end

  def advance_draft_sequence
    if archetype == Archetype.private_message
      DraftSequence.next!(user, Draft::NEW_PRIVATE_MESSAGE)
    else
      DraftSequence.next!(user, Draft::NEW_TOPIC)
    end
  end

  def cancel_auto_close_job
    if (auto_close_at_changed? && !auto_close_at_was.nil?) || (auto_close_user_id_changed? && auto_close_at)
      self.auto_close_started_at ||= Time.zone.now if auto_close_at
      Jobs.cancel_scheduled_job(:close_topic, { topic_id: id })
    end
  end

  def schedule_auto_close_job
    if auto_close_at && (auto_close_at_changed? || auto_close_user_id_changed?)
      options = { topic_id: id, user_id: auto_close_user_id || user_id }
      Jobs.enqueue_at(auto_close_at, :close_topic, options)
    end
  end

  def ensure_topic_has_a_category
    if category_id.nil? && (archetype.nil? || archetype == Archetype.default)
      self.category_id = SiteSetting.uncategorized_category_id
    end
  end

  def self.top_viewed(max = 10)
    Topic.listable_topics.visible.secured.order('views desc').limit(max)
  end

  def self.recent(max = 10)
    Topic.listable_topics.visible.secured.order('created_at desc').limit(max)
  end

  def self.count_exceeds_minimum?
    count > SiteSetting.minimum_topics_similar
  end

  def best_post
    posts.order('score desc').limit(1).first
  end

  def has_flags?
    FlagQuery.flagged_post_actions("active")
             .where("topics.id" => id)
             .exists?
  end

  def all_allowed_users
    allowed_user_ids = allowed_users.select('users.id').to_a
    allowed_group_user_ids = allowed_group_users.select('users.id').to_a
    allowed_staff_ids = private_message? && has_flags? ? User.where(moderator: true).pluck(:id).to_a : []
    User.where('id IN (?)', allowed_user_ids + allowed_group_user_ids + allowed_staff_ids)
  end

  def limit_topics_per_day
    apply_per_day_rate_limit_for("topics", :max_topics_per_day)
    limit_first_day_topics_per_day if user.first_day_user?
  end

  def limit_private_messages_per_day
    return unless private_message?
    apply_per_day_rate_limit_for("pms", :max_private_messages_per_day)
  end

  def fancy_title
    sanitized_title = ERB::Util.html_escape(title)

    return unless sanitized_title
    return sanitized_title unless SiteSetting.title_fancy_entities?

    require 'redcarpet' unless defined? Redcarpet

    Redcarpet::Render::SmartyPants.render(sanitized_title)
  end

  def pending_posts_count
    queued_posts.new_count
  end

  def self.for_digest(user, since, opts=nil)
    opts = opts || {}
    score = "#{ListController.best_period_for(since)}_score"

    topics = Topic
              .visible
              .secured(Guardian.new(user))
              .joins("LEFT OUTER JOIN topic_users ON topic_users.topic_id = topics.id AND topic_users.user_id = #{user.id.to_i}")
              .joins("LEFT OUTER JOIN users ON users.id = topics.user_id")
              .where(closed: false, archived: false)
              .where("COALESCE(topic_users.notification_level, 1) <> ?", TopicUser.notification_levels[:muted])
              .where("COALESCE(users.trust_level, 0) > 0")
              .created_since(since)
              .listable_topics
              .includes(:category)

    if !!opts[:top_order]
      topics = topics.joins("LEFT OUTER JOIN top_topics ON top_topics.topic_id = topics.id")
                     .order(TopicQuerySQL.order_top_for(score))
    end

    if opts[:limit]
      topics = topics.limit(opts[:limit])
    end

    category_topic_ids = Category.pluck(:topic_id).compact!
    if category_topic_ids.present?
      topics = topics.where("topics.id NOT IN (?)", category_topic_ids)
    end

    muted_category_ids = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:muted]).pluck(:category_id)
    if muted_category_ids.present?
      topics = topics.where("topics.category_id NOT IN (?)", muted_category_ids)
    end

    topics
  end

  def self.new_since_last_seen(user, since, featured_topic_ids)
    topics = Topic.for_digest(user, since)
    topics.where("topics.id NOT IN (?)", featured_topic_ids)
  end

  def meta_data=(data)
    custom_fields.replace(data)
  end

  def meta_data
    custom_fields
  end

  def update_meta_data(data)
    custom_fields.update(data)
    save
  end

  def reload(options=nil)
    @post_numbers = nil
    super(options)
  end

  def post_numbers
    @post_numbers ||= posts.order(:post_number).pluck(:post_number)
  end

  def age_in_minutes
    ((Time.zone.now - created_at) / 1.minute).round
  end

  def has_meta_data_boolean?(key)
    meta_data_string(key) == 'true'
  end

  def meta_data_string(key)
    custom_fields[key.to_s]
  end

  def self.listable_count_per_day(start_date, end_date, category_id=nil)
    result = listable_topics.where('created_at >= ? and created_at <= ?', start_date, end_date)
    result = result.where(category_id: category_id) if category_id
    result.group('date(created_at)').order('date(created_at)').count
  end

  def private_message?
    archetype == Archetype.private_message
  end

  MAX_SIMILAR_BODY_LENGTH = 200
  def self.similar_to(title, raw, user=nil)
    return [] unless title.present?
    return [] unless raw.present?

    filter_words = Search.prepare_data(title + " " + raw[0...MAX_SIMILAR_BODY_LENGTH]);
    ts_query = Search.ts_query(filter_words, nil, "|")


    candidates = Topic.visible
       .secured(Guardian.new(user))
       .listable_topics
       .joins('JOIN topic_search_data s ON topics.id = s.topic_id')
       .where("search_data @@ #{ts_query}")
       .order("ts_rank(search_data, #{ts_query}) DESC")
       .limit(SiteSetting.max_similar_results * 3)

    exclude_topic_ids = Category.pluck(:topic_id).compact!
    if exclude_topic_ids.present?
      candidates = candidates.where("topics.id NOT IN (?)", exclude_topic_ids)
    end

    candidate_ids = candidates.pluck(:id)

    return [] unless candidate_ids.present?

    similar = Topic.select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) + similarity(topics.title, :raw) AS similarity, p.cooked as blurb", title: title, raw: raw]))
                     .joins("JOIN posts AS p ON p.topic_id = topics.id AND p.post_number = 1")
                     .limit(SiteSetting.max_similar_results)
                     .where("topics.id IN (?)", candidate_ids)
                     .where("similarity(topics.title, :title) + similarity(topics.title, :raw) > 0.2", raw: raw, title: title)
                     .order('similarity desc')

    similar
  end

  def update_status(status, enabled, user, opts={})
    TopicStatusUpdate.new(self, user).update!(status, enabled, opts)
  end

  def self.next_post_number(topic_id, reply = false)
    highest = exec_sql("select coalesce(max(post_number),0) as max from posts where topic_id = ?", topic_id).first['max'].to_i

    reply_sql = reply ? ", reply_count = reply_count + 1" : ""
    result = exec_sql("UPDATE topics SET highest_post_number = ? + 1#{reply_sql}
                       WHERE id = ? RETURNING highest_post_number", highest, topic_id)
    result.first['highest_post_number'].to_i
  end

  def self.reset_highest(topic_id)
    result = exec_sql "UPDATE topics
                        SET highest_post_number = (SELECT COALESCE(MAX(post_number), 0) FROM posts WHERE topic_id = :topic_id AND deleted_at IS NULL),
                            posts_count = (SELECT count(*) FROM posts WHERE deleted_at IS NULL AND topic_id = :topic_id),
                            last_posted_at = (SELECT MAX(created_at) FROM POSTS WHERE topic_id = :topic_id AND deleted_at IS NULL)
                        WHERE id = :topic_id
                        RETURNING highest_post_number", topic_id: topic_id
    highest_post_number = result.first['highest_post_number'].to_i

    exec_sql "UPDATE topic_users
              SET last_read_post_number = CASE
                                          WHEN last_read_post_number > :highest THEN :highest
                                          ELSE last_read_post_number
                                          END,
                  highest_seen_post_number = CASE
                                    WHEN highest_seen_post_number > :highest THEN :highest
                                    ELSE highest_seen_post_number
                                    END
              WHERE topic_id = :topic_id",
              highest: highest_post_number,
              topic_id: topic_id
  end

  def self.calculate_avg_time(min_topic_age=nil)
    builder = SqlBuilder.new("UPDATE topics
              SET avg_time = x.gmean
              FROM (SELECT topic_id,
                           round(exp(avg(ln(avg_time)))) AS gmean
                    FROM posts
                    WHERE avg_time > 0 AND avg_time IS NOT NULL
                    GROUP BY topic_id) AS x
              /*where*/")

    builder.where("x.topic_id = topics.id AND
                  (topics.avg_time <> x.gmean OR topics.avg_time IS NULL)")

    if min_topic_age
      builder.where("topics.bumped_at > :bumped_at", bumped_at: min_topic_age)
    end

    builder.exec
  end

  def changed_to_category(new_category)
    return true if new_category.blank? || Category.find_by(topic_id: id).present?
    return false if new_category.id == SiteSetting.uncategorized_category_id && !SiteSetting.allow_uncategorized_topics

    Topic.transaction do
      old_category = category

      if self.category_id != new_category.id
        self.category_id = new_category.id
        self.update_column(:category_id, new_category.id)
        Category.where(id: old_category.id).update_all("topic_count = topic_count - 1") if old_category
      end

      Category.where(id: new_category.id).update_all("topic_count = topic_count + 1")
      CategoryFeaturedTopic.feature_topics_for(old_category) unless @import_mode
      CategoryFeaturedTopic.feature_topics_for(new_category) unless @import_mode || old_category.id == new_category.id
      CategoryUser.auto_watch_new_topic(self, new_category)
      CategoryUser.auto_track_new_topic(self, new_category)
    end

    true
  end

  def add_moderator_post(user, text, opts=nil)
    opts ||= {}
    new_post = nil
    Topic.transaction do
      creator = PostCreator.new(user,
                                raw: text,
                                post_type: opts[:post_type] || Post.types[:moderator_action],
                                action_code: opts[:action_code],
                                no_bump: opts[:bump].blank?,
                                skip_notifications: opts[:skip_notifications],
                                topic_id: self.id,
                                skip_validations: true)
      new_post = creator.create
      increment!(:moderator_posts_count)
    end

    if new_post.present?
      new_post.update_attributes(post_number: opts[:post_number], sort_order: opts[:post_number]) if opts[:post_number].present?

      TopicLink.extract_from(new_post)
      QuotedPost.extract_from(new_post)
    end

    new_post
  end

  def change_category_to_id(category_id)
    return false if private_message?

    new_category_id = category_id.to_i
    new_category_id = SiteSetting.uncategorized_category_id if new_category_id == 0

    return true if self.category_id == new_category_id

    cat = Category.find_by(id: new_category_id)
    return false unless cat

    changed_to_category(cat)
  end

  def remove_allowed_user(username)
    if user = User.find_by(username: username)
      topic_user = topic_allowed_users.find_by(user_id: user.id)
      if topic_user
        topic_user.destroy
        return true
      end
    end

    false
  end

  def invite(invited_by, username_or_email, group_ids=nil)
    if private_message?
      user = User.find_by_username_or_email(username_or_email)
      if user && topic_allowed_users.create!(user_id: user.id)

        user.notifications.create(notification_type: Notification.types[:invited_to_private_message],
                                  topic_id: id,
                                  post_number: 1,
                                  data: { topic_title: title,
                                          display_username: invited_by.username }.to_json)
        return true
      end
    end

    if username_or_email =~ /^.+@.+$/ && !SiteSetting.enable_sso
      RateLimiter.new(invited_by, "topic-invitations-per-day", SiteSetting.max_topic_invitations_per_day, 1.day.to_i).performed!

      invite_by_email(invited_by, username_or_email, group_ids)
    else
      user = User.find_by_username(username_or_email)
      if user && topic_allowed_users.create!(user_id: user.id)
        RateLimiter.new(invited_by, "topic-invitations-per-day", SiteSetting.max_topic_invitations_per_day, 1.day.to_i).performed!

        user.notifications.create(notification_type: Notification.types[:invited_to_topic],
                                  topic_id: id,
                                  post_number: 1,
                                  data: { topic_title: title,
                                          display_username: invited_by.username }.to_json)
        return true
      else
        false
      end
    end
  end

  def invite_by_email(invited_by, email, group_ids=nil)
    Invite.invite_by_email(email, invited_by, self, group_ids)
  end

  def email_already_exists_for?(invite)
    invite.email_already_exists and private_message?
  end

  def grant_permission_to_user(lower_email)
    user = User.find_by(email: lower_email)
    topic_allowed_users.create!(user_id: user.id)
  end

  def max_post_number
    posts.with_deleted.maximum(:post_number).to_i
  end

  def move_posts(moved_by, post_ids, opts)
    post_mover = PostMover.new(self, moved_by, post_ids)

    if opts[:destination_topic_id]
      post_mover.to_topic opts[:destination_topic_id]
    elsif opts[:title]
      post_mover.to_new_topic(opts[:title], opts[:category_id])
    end
  end

  def update_statistics
    feature_topic_users
    update_action_counts
    Topic.reset_highest(id)
  end

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def update_action_counts
    PostActionType.types.each_key do |type|
      count_field = "#{type}_count"
      update_column(count_field, Post.where(topic_id: id).sum(count_field))
    end
  end

  def posters_summary(options = {})
    @posters_summary ||= TopicPostersSummary.new(self, options).summary
  end

  def participants_summary(options = {})
    @participants_summary ||= TopicParticipantsSummary.new(self, options).summary
  end

  def make_banner!(user)
    previous_banner = Topic.where(archetype: Archetype.banner).first
    previous_banner.remove_banner!(user) if previous_banner.present?

    self.archetype = Archetype.banner
    self.add_moderator_post(user, I18n.t("archetypes.banner.message.make"))
    self.save

    MessageBus.publish('/site/banner', banner)
  end

  def remove_banner!(user)
    self.archetype = Archetype.default
    self.add_moderator_post(user, I18n.t("archetypes.banner.message.remove"))
    self.save

    MessageBus.publish('/site/banner', nil)
  end

  def banner
    post = self.posts.order(:post_number).limit(1).first

    {
      html: post.cooked,
      key: self.id,
      url: self.url
    }
  end

  def slug
    unless slug = read_attribute(:slug)
      return '' unless title.present?
      slug = Slug.for(title)
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def title=(t)
    slug = Slug.for(t.to_s)
    write_attribute(:slug, slug)
    write_attribute(:title,t)
  end

  def last_post_url
    "#{Discourse.base_uri}/t/#{slug}/#{id}/#{posts_count}"
  end

  def self.url(id, slug, post_number=nil)
    url = "#{Discourse.base_url}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def url(post_number = nil)
    self.class.url id, slug, post_number
  end

  def relative_url(post_number=nil)
    url = "#{Discourse.base_uri}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def unsubscribe_url
    "#{url}/unsubscribe"
  end

  def clear_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: Time.now)
  end

  def re_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: nil)
  end

  def update_pinned(status, global=false, pinned_until=nil)
    pinned_until = Time.parse(pinned_until) rescue nil

    update_columns(
      pinned_at: status ? Time.now : nil,
      pinned_globally: global,
      pinned_until: pinned_until
    )

    Jobs.cancel_scheduled_job(:unpin_topic, topic_id: self.id)
    Jobs.enqueue_at(pinned_until, :unpin_topic, topic_id: self.id) if pinned_until
  end

  def draft_key
    "#{Draft::EXISTING_TOPIC}#{id}"
  end

  def notifier
    @topic_notifier ||= TopicNotifier.new(self)
  end

  def muted?(user)
    if user && user.id
      notifier.muted?(user.id)
    end
  end

  def self.ensure_consistency!
    Topic.where("pinned_until < now()").update_all(pinned_at: nil, pinned_globally: false, pinned_until: nil)
  end

  def self.auto_close
    Topic.where("NOT closed AND auto_close_at < ? AND auto_close_user_id IS NOT NULL", 1.minute.ago).each do |t|
      t.auto_close
    end
  end

  def auto_close(closer = nil)
    if auto_close_at && !closed? && !deleted_at && auto_close_at < 5.minutes.from_now
      closer ||= auto_close_user
      if Guardian.new(closer).can_moderate?(self)
        update_status('autoclosed', true, closer)
      end
    end
  end

  def set_auto_close(arg, opts={})
    self.auto_close_hours = nil
    by_user = opts[:by_user]
    offset_minutes = opts[:timezone_offset]

    if self.auto_close_based_on_last_post
      num_hours = arg.to_f
      if num_hours > 0
        last_post_created_at = self.ordered_posts.last.try(:created_at) || Time.zone.now
        self.auto_close_at = last_post_created_at + num_hours.hours
        self.auto_close_hours = num_hours
      else
        self.auto_close_at = nil
      end
    else
      utc = Time.find_zone("UTC")
      if arg.is_a?(String) && m = /^(\d{1,2}):(\d{2})(?:\s*[AP]M)?$/i.match(arg.strip)
        now = utc.now
        self.auto_close_at = utc.local(now.year, now.month, now.day, m[1].to_i, m[2].to_i)
        self.auto_close_at += offset_minutes * 60 if offset_minutes
        self.auto_close_at += 1.day if self.auto_close_at < now
      elsif arg.is_a?(String) && arg.include?("-") && timestamp = utc.parse(arg)
        self.auto_close_at = timestamp
        self.auto_close_at += offset_minutes * 60 if offset_minutes
        self.errors.add(:auto_close_at, :invalid) if timestamp < Time.zone.now
      else
        num_hours = arg.to_f
        if num_hours > 0
          self.auto_close_at = num_hours.hours.from_now
          self.auto_close_hours = num_hours
        else
          self.auto_close_at = nil
        end
      end
    end

    if self.auto_close_at.nil?
      self.auto_close_started_at = nil
    else
      if self.auto_close_based_on_last_post
        self.auto_close_started_at = Time.zone.now
      else
        self.auto_close_started_at ||= Time.zone.now
      end
      if by_user.try(:staff?) || by_user.try(:trust_level) == TrustLevel[4]
        self.auto_close_user = by_user
      else
        self.auto_close_user ||= (self.user.staff? || self.user.trust_level == TrustLevel[4] ? self.user : Discourse.system_user)
      end
    end

    self
  end

  def read_restricted_category?
    category && category.read_restricted
  end

  def acting_user
    @acting_user || user
  end

  def acting_user=(u)
    @acting_user = u
  end

  def secure_group_ids
    @secure_group_ids ||= if self.category && self.category.read_restricted?
      self.category.secure_group_ids
    end
  end

  def has_topic_embed?
    TopicEmbed.where(topic_id: id).exists?
  end

  def expandable_first_post?
    SiteSetting.embed_truncate? && has_topic_embed?
  end

  TIME_TO_FIRST_RESPONSE_SQL ||= <<-SQL
    SELECT AVG(t.hours)::float AS "hours", t.created_at AS "date"
    FROM (
      SELECT t.id, t.created_at::date AS created_at, EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at)::float / 3600.0 AS "hours"
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id
      /*where*/
      GROUP BY t.id
    ) t
    GROUP BY t.created_at
    ORDER BY t.created_at
  SQL

  TIME_TO_FIRST_RESPONSE_TOTAL_SQL ||= <<-SQL
    SELECT AVG(t.hours)::float AS "hours"
    FROM (
      SELECT t.id, EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at)::float / 3600.0 AS "hours"
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id
      /*where*/
      GROUP BY t.id
    ) t
  SQL

  def self.time_to_first_response(sql, opts=nil)
    opts ||= {}
    builder = SqlBuilder.new(sql)
    builder.where("t.created_at >= :start_date", start_date: opts[:start_date]) if opts[:start_date]
    builder.where("t.created_at < :end_date", end_date: opts[:end_date]) if opts[:end_date]
    builder.where("t.category_id = :category_id", category_id: opts[:category_id]) if opts[:category_id]
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.where("p.deleted_at IS NULL")
    builder.where("p.post_number > 1")
    builder.where("p.user_id != t.user_id")
    builder.where("EXTRACT(EPOCH FROM p.created_at - t.created_at) > 0")
    builder.exec
  end

  def self.time_to_first_response_per_day(start_date, end_date, category_id=nil)
    time_to_first_response(TIME_TO_FIRST_RESPONSE_SQL, start_date: start_date, end_date: end_date, category_id: category_id)
  end

  def self.time_to_first_response_total(opts=nil)
    total = time_to_first_response(TIME_TO_FIRST_RESPONSE_TOTAL_SQL, opts)
    total.first["hours"].to_f.round(2)
  end

  WITH_NO_RESPONSE_SQL ||= <<-SQL
    SELECT COUNT(*) as count, tt.created_at AS "date"
    FROM (
      SELECT t.id, t.created_at::date AS created_at, MIN(p.post_number) first_reply
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id AND p.user_id != t.user_id AND p.deleted_at IS NULL
      /*where*/
      GROUP BY t.id
    ) tt
    WHERE tt.first_reply IS NULL
    GROUP BY tt.created_at
    ORDER BY tt.created_at
  SQL

  def self.with_no_response_per_day(start_date, end_date, category_id=nil)
    builder = SqlBuilder.new(WITH_NO_RESPONSE_SQL)
    builder.where("t.created_at >= :start_date", start_date: start_date) if start_date
    builder.where("t.created_at < :end_date", end_date: end_date) if end_date
    builder.where("t.category_id = :category_id", category_id: category_id) if category_id
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.exec
  end

  WITH_NO_RESPONSE_TOTAL_SQL ||= <<-SQL
    SELECT COUNT(*) as count
    FROM (
      SELECT t.id, MIN(p.post_number) first_reply
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id AND p.user_id != t.user_id AND p.deleted_at IS NULL
      /*where*/
      GROUP BY t.id
    ) tt
    WHERE tt.first_reply IS NULL
  SQL

  def self.with_no_response_total(opts={})
    builder = SqlBuilder.new(WITH_NO_RESPONSE_TOTAL_SQL)
    builder.where("t.category_id = :category_id", category_id: opts[:category_id]) if opts[:category_id]
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.exec.first["count"].to_i
  end

  private

  def update_category_topic_count_by(num)
    if category_id.present?
      Category.where(['id = ?', category_id]).update_all("topic_count = topic_count " + (num > 0 ? '+' : '') + "#{num}")
    end
  end

  def limit_first_day_topics_per_day
    apply_per_day_rate_limit_for("first-day-topics", :max_topics_in_first_day)
  end

  def apply_per_day_rate_limit_for(key, method_name)
    #nodyna <send-375> <SD EASY (change-prone variables)>
    RateLimiter.new(user, "#{key}-per-day", SiteSetting.send(method_name), 1.day.to_i)
  end

end


