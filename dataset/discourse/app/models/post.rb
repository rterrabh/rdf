require_dependency 'jobs/base'
require_dependency 'pretty_text'
require_dependency 'rate_limiter'
require_dependency 'post_revisor'
require_dependency 'enum'
require_dependency 'post_analyzer'
require_dependency 'validators/post_validator'
require_dependency 'plugin/filter'
require_dependency 'email_cook'

require 'archetype'
require 'digest/sha1'

class Post < ActiveRecord::Base
  include RateLimiter::OnCreateRecord
  include Trashable
  include HasCustomFields
  include LimitedEdit

  BAKED_VERSION = 1

  rate_limit
  rate_limit :limit_posts_per_day

  belongs_to :user
  belongs_to :topic, counter_cache: :posts_count

  belongs_to :reply_to_user, class_name: "User"

  has_many :post_replies
  has_many :replies, through: :post_replies
  has_many :post_actions
  has_many :topic_links

  has_many :post_uploads
  has_many :uploads, through: :post_uploads

  has_one :post_search_data
  has_one :post_stat

  has_many :post_details

  has_many :post_revisions
  has_many :revisions, foreign_key: :post_id, class_name: 'PostRevision'

  has_many :user_actions, foreign_key: :target_post_id

  validates_with ::Validators::PostValidator

  attr_accessor :image_sizes, :quoted_post_numbers, :no_bump, :invalidate_oneboxes, :cooking_options, :skip_unique_check

  SHORT_POST_CHARS = 1200

  scope :by_newest, -> { order('created_at desc, id desc') }
  scope :by_post_number, -> { order('post_number ASC') }
  scope :with_user, -> { includes(:user) }
  scope :created_since, lambda { |time_ago| where('posts.created_at > ?', time_ago) }
  scope :public_posts, -> { joins(:topic).where('topics.archetype <> ?', Archetype.private_message) }
  scope :private_posts, -> { joins(:topic).where('topics.archetype = ?', Archetype.private_message) }
  scope :with_topic_subtype, ->(subtype) { joins(:topic).where('topics.subtype = ?', subtype) }
  scope :visible, -> { joins(:topic).where('topics.visible = true').where(hidden: false) }

  delegate :username, to: :user

  def self.hidden_reasons
    @hidden_reasons ||= Enum.new(
      :flag_threshold_reached,
      :flag_threshold_reached_again,
      :new_user_spam_threshold_reached,
      :flagged_by_tl3_user
    )
  end

  def self.types
    @types ||= Enum.new(:regular, :moderator_action, :small_action)
  end

  def self.cook_methods
    @cook_methods ||= Enum.new(:regular, :raw_html, :email)
  end

  def self.find_by_detail(key, value)
    includes(:post_details).find_by(post_details: { key: key, value: value })
  end

  def add_detail(key, value, extra = nil)
    post_details.build(key: key, value: value, extra: extra)
  end

  def limit_posts_per_day
    if user.first_day_user? && post_number && post_number > 1
      RateLimiter.new(user, "first-day-replies-per-day", SiteSetting.max_replies_in_first_day, 1.day.to_i)
    end
  end

  def publish_change_to_clients!(type)
    MessageBus.publish("/topic/#{topic_id}", {
      id: id,
      post_number: post_number,
      updated_at: Time.now,
      type: type
    }, group_ids: topic.secure_group_ids) if topic
  end

  def trash!(trashed_by=nil)
    self.topic_links.each(&:destroy)
    super(trashed_by)
  end

  def recover!
    super
    update_flagged_posts_count
    TopicLink.extract_from(self)
    QuotedPost.extract_from(self)
    if topic && topic.category_id && topic.category
      topic.category.update_latest
    end
  end

  def unique_post_key
    "unique-post-#{user_id}:#{raw_hash}"
  end

  def store_unique_post_key
    if SiteSetting.unique_posts_mins > 0
      $redis.setex(unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, id)
    end
  end

  def matches_recent_post?
    post_id = $redis.get(unique_post_key)
    post_id != nil and post_id.to_i != id
  end

  def raw_hash
    return if raw.blank?
    Digest::SHA1.hexdigest(raw)
  end

  def self.white_listed_image_classes
    @white_listed_image_classes ||= ['avatar', 'favicon', 'thumbnail']
  end

  def post_analyzer
    @post_analyzers ||= {}
    @post_analyzers[raw_hash] ||= PostAnalyzer.new(raw, topic_id)
  end

  %w{raw_mentions linked_hosts image_count attachment_count link_count raw_links}.each do |attr|
    #nodyna <define_method-397> <DM MODERATE (array)>
    define_method(attr) do
      #nodyna <send-398> <SD MODERATE (change-prone variables)>
      post_analyzer.send(attr)
    end
  end

  def cook(*args)
    return raw if cook_method == Post.cook_methods[:raw_html]

    cooked = nil
    if cook_method == Post.cook_methods[:email]
      cooked = EmailCook.new(raw).cook
    else
      cooked = if !self.user || SiteSetting.tl3_links_no_follow || !self.user.has_trust_level?(TrustLevel[3])
                 post_analyzer.cook(*args)
               else
                 cloned = args.dup
                 cloned[1] ||= {}
                 cloned[1][:omit_nofollow] = true
                 post_analyzer.cook(*cloned)
               end
    end

    new_cooked = Plugin::Filter.apply(:after_post_cook, self, cooked)

    if post_type == Post.types[:regular]
      if new_cooked != cooked && new_cooked.blank?
        Rails.logger.warn("Plugin is blanking out post: #{self.url}\nraw: #{self.raw}")
      elsif new_cooked.blank?
        Rails.logger.warn("Blank post detected post: #{self.url}\nraw: #{self.raw}")
      end
    end

    new_cooked
  end

  def acting_user
    @acting_user || user
  end

  def acting_user=(pu)
    @acting_user = pu
  end

  def whitelisted_spam_hosts

    hosts = SiteSetting
              .white_listed_spam_host_domains
              .split('|')
              .map{|h| h.strip}
              .reject{|h| !h.include?('.')}

    hosts << GlobalSetting.hostname
    hosts << RailsMultisite::ConnectionManagement.current_hostname

  end

  def total_hosts_usage
    hosts = linked_hosts.clone
    whitelisted = whitelisted_spam_hosts

    hosts.reject! do |h|
      whitelisted.any? do |w|
        h.end_with?(w)
      end
    end

    return hosts if hosts.length == 0

    TopicLink.where(domain: hosts.keys, user_id: acting_user.id)
             .group(:domain, :post_id)
             .count.each_key do |tuple|
      domain = tuple[0]
      hosts[domain] = (hosts[domain] || 0) + 1
    end

    hosts
  end

  def has_host_spam?
    return false if acting_user.present? && acting_user.has_trust_level?(TrustLevel[1])

    total_hosts_usage.each do |_, count|
      return true if count >= SiteSetting.newuser_spam_host_threshold
    end

    false
  end

  def archetype
    topic.archetype
  end

  def self.regular_order
    order(:sort_order, :post_number)
  end

  def self.reverse_order
    order('sort_order desc, post_number desc')
  end

  def self.summary(topic_id=nil)
    topic_id = topic_id ? topic_id.to_i : "posts.topic_id"

    where(["post_number = 1 or id in (
            SELECT p1.id
            FROM posts p1
            WHERE p1.percent_rank <= ? AND
               p1.topic_id = #{topic_id}
            ORDER BY p1.percent_rank
            LIMIT ?
          )",
           SiteSetting.summary_percent_filter.to_f / 100.0,
           SiteSetting.summary_max_results
    ])
  end

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def filter_quotes(parent_post = nil)
    return cooked if parent_post.blank?

    return cooked unless (quote_count == 1)

    parent_raw = parent_post.raw.sub(/\[quote.+\/quote\]/m, '')

    if raw[parent_raw] || (parent_raw.size < SHORT_POST_CHARS)
      return cooked.sub(/\<aside.+\<\/aside\>/m, '')
    end

    cooked
  end

  def external_id
    "#{topic_id}/#{post_number}"
  end

  def reply_to_post
    return if reply_to_post_number.blank?
    @reply_to_post ||= Post.find_by("topic_id = :topic_id AND post_number = :post_number", topic_id: topic_id, post_number: reply_to_post_number)
  end

  def reply_notification_target
    return if reply_to_post_number.blank?
    Post.find_by("topic_id = :topic_id AND post_number = :post_number AND user_id <> :user_id", topic_id: topic_id, post_number: reply_to_post_number, user_id: user_id).try(:user)
  end

  def self.excerpt(cooked, maxlength = nil, options = {})
    maxlength ||= SiteSetting.post_excerpt_maxlength
    PrettyText.excerpt(cooked, maxlength, options)
  end

  def excerpt(maxlength = nil, options = {})
    Post.excerpt(cooked, maxlength, options)
  end

  def is_first_post?
    post_number.blank? ?
      topic.try(:highest_post_number) == 0 :
      post_number == 1
  end

  def is_flagged?
    post_actions.where(post_action_type_id: PostActionType.flag_types.values, deleted_at: nil).count != 0
  end

  def unhide!
    self.update_attributes(hidden: false, hidden_at: nil, hidden_reason_id: nil)
    self.topic.update_attributes(visible: true) if is_first_post?
    save(validate: false)
    publish_change_to_clients!(:acted)
  end

  def url
    if topic
      Post.url(topic.slug, topic.id, post_number)
    else
      "/404"
    end
  end

  def self.url(slug, topic_id, post_number)
    "/t/#{slug}/#{topic_id}/#{post_number}"
  end

  def self.urls(post_ids)
    ids = post_ids.map{|u| u}
    if ids.length > 0
      urls = {}
      Topic.joins(:posts).where('posts.id' => ids).
        select(['posts.id as post_id','post_number', 'topics.slug', 'topics.title', 'topics.id']).
      each do |t|
        urls[t.post_id.to_i] = url(t.slug, t.id, t.post_number)
      end
      urls
    else
      {}
    end
  end

  def revise(updated_by, changes={}, opts={})
    PostRevisor.new(self).revise!(updated_by, changes, opts)
  end

  def self.rebake_old(limit)
    problems = []
    Post.where('baked_version IS NULL OR baked_version < ?', BAKED_VERSION)
        .limit(limit).each do |p|
      begin
        p.rebake!
      rescue => e
        problems << {post: p, ex: e}
      end
    end
    problems
  end

  def rebake!(opts=nil)
    opts ||= {}

    new_cooked = cook(raw, topic_id: topic_id, invalidate_oneboxes: opts.fetch(:invalidate_oneboxes, false))
    old_cooked = cooked

    update_columns(cooked: new_cooked, baked_at: Time.new, baked_version: BAKED_VERSION)

    TopicLink.extract_from(self)
    QuotedPost.extract_from(self)

    trigger_post_process(true)

    publish_change_to_clients!(:rebaked)

    new_cooked != old_cooked
  end

  def set_owner(new_user, actor)
    return if user_id == new_user.id

    edit_reason = I18n.t('change_owner.post_revision_text',
      old_user: (self.user.username_lower rescue nil) || I18n.t('change_owner.deleted_user'),
      new_user: new_user.username_lower
    )

    revise(actor, { raw: self.raw, user_id: new_user.id, edit_reason: edit_reason })
  end

  before_create do
    PostCreator.before_create_tasks(self)
  end

  def self.calculate_avg_time(min_topic_age=nil)
    retry_lock_error do
      builder = SqlBuilder.new("UPDATE posts
                SET avg_time = (x.gmean / 1000)
                FROM (SELECT post_timings.topic_id,
                             post_timings.post_number,
                             round(exp(avg(ln(msecs)))) AS gmean
                      FROM post_timings
                      INNER JOIN posts AS p2
                        ON p2.post_number = post_timings.post_number
                          AND p2.topic_id = post_timings.topic_id
                          AND p2.user_id <> post_timings.user_id
                      GROUP BY post_timings.topic_id, post_timings.post_number) AS x
                /*where*/")

      builder.where("x.topic_id = posts.topic_id
                  AND x.post_number = posts.post_number
                  AND (posts.avg_time <> (x.gmean / 1000)::int OR posts.avg_time IS NULL)")

      if min_topic_age
        builder.where("posts.topic_id IN (SELECT id FROM topics where bumped_at > :bumped_at)",
                     bumped_at: min_topic_age)
      end

      builder.exec
    end
  end

  before_save do
    self.last_editor_id ||= user_id
    self.cooked = cook(raw, topic_id: topic_id) unless new_record?
    self.baked_at = Time.new
    self.baked_version = BAKED_VERSION
  end

  def advance_draft_sequence
    return if topic.blank? # could be deleted
    DraftSequence.next!(last_editor_id, topic.draft_key)
  end

  def extract_quoted_post_numbers
    temp_collector = []

    raw.scan(/\[quote=\"([^"]+)"\]/).each do |quote|
      args = parse_quote_into_arguments(quote)
      temp_collector << args[:post] unless (args[:topic].present? && topic_id != args[:topic])
    end

    temp_collector.uniq!
    self.quoted_post_numbers = temp_collector
    self.quote_count = temp_collector.size
  end


  def save_reply_relationships
    add_to_quoted_post_numbers(reply_to_post_number)
    return if self.quoted_post_numbers.blank?

    self.quoted_post_numbers.each do |p|
      post = Post.find_by(topic_id: topic_id, post_number: p)
      create_reply_relationship_with(post)
    end
  end

  def trigger_post_process(bypass_bump = false)
    args = {
      post_id: id,
      bypass_bump: bypass_bump
    }
    args[:image_sizes] = image_sizes if image_sizes.present?
    args[:invalidate_oneboxes] = true if invalidate_oneboxes.present?
    Jobs.enqueue(:process_post, args)
  end

  def self.public_posts_count_per_day(start_date, end_date, category_id=nil)
    result = public_posts.where('posts.created_at >= ? AND posts.created_at <= ?', start_date, end_date)
    result = result.where('topics.category_id = ?', category_id) if category_id
    result.group('date(posts.created_at)').order('date(posts.created_at)').count
  end

  def self.private_messages_count_per_day(since_days_ago, topic_subtype)
    private_posts.with_topic_subtype(topic_subtype).where('posts.created_at > ?', since_days_ago.days.ago).group('date(posts.created_at)').order('date(posts.created_at)').count
  end

  def reply_history(max_replies=100)
    post_ids = Post.exec_sql("WITH RECURSIVE breadcrumb(id, reply_to_post_number) AS (
                              SELECT p.id, p.reply_to_post_number FROM posts AS p
                                WHERE p.id = :post_id
                              UNION
                                 SELECT p.id, p.reply_to_post_number FROM posts AS p, breadcrumb
                                   WHERE breadcrumb.reply_to_post_number = p.post_number
                                     AND p.topic_id = :topic_id
                            ) SELECT id from breadcrumb ORDER by id", post_id: id, topic_id: topic_id).to_a

    post_ids.map! {|r| r['id'].to_i }
            .reject! {|post_id| post_id == id}

    post_ids = (post_ids[(0-max_replies)..-1] || post_ids)

    Post.where(id: post_ids).includes(:user, :topic).order(:id).to_a
  end

  def revert_to(number)
    return if number >= version
    post_revision = PostRevision.find_by(post_id: id, number: (number + 1))
    post_revision.modifications.each do |attribute, change|
      attribute = "version" if attribute == "cached_version"
      write_attribute(attribute, change[0])
    end
  end

  def self.rebake_all_quoted_posts(user_id)
    return if user_id.blank?

    Post.exec_sql <<-SQL
      WITH user_quoted_posts AS (
        SELECT post_id
          FROM quoted_posts
         WHERE quoted_post_id IN (SELECT id FROM posts WHERE user_id = #{user_id})
      )
      UPDATE posts
         SET baked_version = NULL
       WHERE baked_version IS NOT NULL
         AND id IN (SELECT post_id FROM user_quoted_posts)
    SQL
  end

  private

  def parse_quote_into_arguments(quote)
    return {} unless quote.present?
    args = HashWithIndifferentAccess.new
    quote.first.scan(/([a-z]+)\:(\d+)/).each do |arg|
      args[arg[0]] = arg[1].to_i
    end
    args
  end

  def add_to_quoted_post_numbers(num)
    return unless num.present?
    self.quoted_post_numbers ||= []
    self.quoted_post_numbers << num
  end

  def create_reply_relationship_with(post)
    return if post.nil?
    post_reply = post.post_replies.new(reply_id: id)
    if post_reply.save
      Post.where(id: post.id).update_all ['reply_count = reply_count + 1']
    end
  end

end

