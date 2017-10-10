require_dependency 'rate_limiter'
require_dependency 'topic_creator'
require_dependency 'post_jobs_enqueuer'
require_dependency 'distributed_mutex'
require_dependency 'has_errors'

class PostCreator
  include HasErrors

  attr_reader :opts

  def initialize(user, opts)
    @user = user
    @opts = opts || {}
    opts[:title] = pg_clean_up(opts[:title]) if opts[:title] && opts[:title].include?("\u0000")
    opts[:raw] = pg_clean_up(opts[:raw]) if opts[:raw] && opts[:raw].include?("\u0000")
    @spam = false
  end

  def pg_clean_up(str)
    str.gsub("\u0000", "")
  end

  def spam?
    @spam
  end

  def skip_validations?
    @opts[:skip_validations]
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def valid?
    @topic = nil
    @post = nil

    if @user.suspended? && !skip_validations?
      errors[:base] << I18n.t(:user_is_suspended)
      return false
    end

    if new_topic?
      topic_creator = TopicCreator.new(@user, guardian, @opts)
      return false unless skip_validations? || validate_child(topic_creator)
    else
      @topic = Topic.find_by(id: @opts[:topic_id])
      if (@topic.blank? || !guardian.can_create?(Post, @topic))
        errors[:base] << I18n.t(:topic_not_found)
        return false
      end
    end

    setup_post

    return true if skip_validations?
    if @post.has_host_spam?
      @spam = true
      errors[:base] << I18n.t(:spamming_host)
      return false
    end

    DiscourseEvent.trigger :before_create_post, @post
    DiscourseEvent.trigger :validate_post, @post

    post_validator = Validators::PostValidator.new(skip_topic: true)
    post_validator.validate(@post)

    valid = @post.errors.blank?
    add_errors_from(@post) unless valid
    valid
  end

  def create
    if valid?
      transaction do
        build_post_stats
        create_topic
        save_post
        extract_links
        store_unique_post_key
        track_topic
        update_topic_stats
        update_topic_auto_close
        update_user_counts
        create_embedded_topic

        ensure_in_allowed_users if guardian.is_staff?
        @post.advance_draft_sequence
        @post.save_reply_relationships
      end
    end

    if @post && errors.blank?
      publish

      track_latest_on_category
      enqueue_jobs
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: @post)

      trigger_after_events(@post)
    end

    if @post || @spam
      handle_spam unless @opts[:import_mode]
    end

    @post
  end

  def self.track_post_stats
    Rails.env != "test".freeze || @track_post_stats
  end

  def self.track_post_stats=(val)
    @track_post_stats = val
  end

  def self.create(user, opts)
    PostCreator.new(user, opts).create
  end

  def self.before_create_tasks(post)
    set_reply_user_id(post)

    post.word_count = post.raw.scan(/\w+/).size
    post.post_number ||= Topic.next_post_number(post.topic_id, post.reply_to_post_number.present?)

    cooking_options = post.cooking_options || {}
    cooking_options[:topic_id] = post.topic_id

    post.cooked ||= post.cook(post.raw, cooking_options)
    post.sort_order = post.post_number
    post.last_version_at ||= Time.now
  end

  def self.set_reply_user_id(post)
    return unless post.reply_to_post_number.present?

    post.reply_to_user_id ||= Post.select(:user_id).find_by(topic_id: post.topic_id, post_number: post.reply_to_post_number).try(:user_id)
  end

  protected

  def build_post_stats
    if PostCreator.track_post_stats
      draft_key = @topic ? "topic_#{@topic.id}" : "new_topic"

      sequence = DraftSequence.current(@user, draft_key)
      revisions = Draft.where(sequence: sequence,
                              user_id: @user.id,
                              draft_key: draft_key).pluck(:revisions).first || 0

      @post.build_post_stat(
        drafts_saved: revisions,
        typing_duration_msecs: @opts[:typing_duration_msecs] || 0,
        composer_open_duration_msecs: @opts[:composer_open_duration_msecs] || 0
      )
    end
  end

  def trigger_after_events(post)
    DiscourseEvent.trigger(:topic_created, post.topic, @opts, @user) unless @opts[:topic_id]
    DiscourseEvent.trigger(:post_created, post, @opts, @user)
  end

  def transaction(&blk)
    Post.transaction do
      if new_topic?
        blk.call
      else
        DistributedMutex.synchronize("topic_id_#{@opts[:topic_id]}", &blk)
      end
    end
  end

  def create_embedded_topic
    return unless @opts[:embed_url].present?
    embed = TopicEmbed.new(topic_id: @post.topic_id, post_id: @post.id, embed_url: @opts[:embed_url])
    rollback_from_errors!(embed) unless embed.save
  end

  def handle_spam
    if @spam
      GroupMessage.create( Group[:moderators].name,
                           :spam_post_blocked,
                           { user: @user,
                             limit_once_per: 24.hours,
                             message_params: {domains: @post.linked_hosts.keys.join(', ')} } )
    elsif @post && errors.blank? && !skip_validations?
      SpamRulesEnforcer.enforce!(@post)
    end
  end

  def track_latest_on_category
    return unless @post && @post.errors.count == 0 && @topic && @topic.category_id

    Category.where(id: @topic.category_id).update_all(latest_post_id: @post.id)
    Category.where(id: @topic.category_id).update_all(latest_topic_id: @topic.id) if @post.is_first_post?
  end

  def ensure_in_allowed_users
    return unless @topic.private_message?

    unless @topic.topic_allowed_users.where(user_id: @user.id).exists?
      @topic.topic_allowed_users.create!(user_id: @user.id)
    end
  end

  private

  def create_topic
    return if @topic
    begin
      topic_creator = TopicCreator.new(@user, guardian, @opts)
      @topic = topic_creator.create
    rescue ActiveRecord::Rollback
      add_errors_from(topic_creator)
      return
    end
    @post.topic_id = @topic.id
    @post.topic = @topic
  end

  def update_topic_stats
    attrs = {
      last_posted_at: @post.created_at,
      last_post_user_id: @post.user_id,
      word_count: (@topic.word_count || 0) + @post.word_count,
    }
    attrs[:excerpt] = @post.excerpt(220, strip_links: true) if new_topic?
    attrs[:bumped_at] = @post.created_at unless @post.no_bump
    @topic.update_attributes(attrs)
  end

  def update_topic_auto_close
    if @topic.auto_close_based_on_last_post && @topic.auto_close_hours
      @topic.set_auto_close(@topic.auto_close_hours).save
    end
  end

  def setup_post
    @opts[:raw] = TextCleaner.normalize_whitespaces(@opts[:raw] || '').gsub(/\s+\z/, "")

    post = Post.new(raw: @opts[:raw],
                    topic_id: @topic.try(:id),
                    user: @user,
                    reply_to_post_number: @opts[:reply_to_post_number])

    [:post_type, :no_bump, :cooking_options, :image_sizes, :acting_user, :invalidate_oneboxes, :cook_method, :via_email, :raw_email, :action_code].each do |a|
      #nodyna <send-345> <SD MODERATE (array)>
      post.send("#{a}=", @opts[a]) if @opts[a].present?
    end

    post.extract_quoted_post_numbers
    post.created_at = Time.zone.parse(@opts[:created_at].to_s) if @opts[:created_at].present?

    if fields = @opts[:custom_fields]
      post.custom_fields = fields
    end

    @post = post
  end

  def save_post
    @post.disable_rate_limits! if skip_validations?
    saved = @post.save(validate: !skip_validations?)
    rollback_from_errors!(@post) unless saved
  end

  def store_unique_post_key
    @post.store_unique_post_key
  end

  def update_user_counts
    @user.create_user_stat if @user.user_stat.nil?

    if @user.user_stat.first_post_created_at.nil?
      @user.user_stat.first_post_created_at = @post.created_at
    end

    @user.user_stat.post_count += 1
    @user.user_stat.topic_count += 1 if @post.is_first_post?

    if !@opts[:import_mode] && @user.id != @topic.user_id
      @user.user_stat.update_topic_reply_count
    end

    @user.user_stat.save!

    @user.update_attributes(last_posted_at: @post.created_at)
  end

  def publish
    return if @opts[:import_mode]
    return unless @post.post_number > 1

    @post.publish_change_to_clients! :created
  end

  def extract_links
    TopicLink.extract_from(@post)
    QuotedPost.extract_from(@post)
  end

  def track_topic
    return if @opts[:auto_track] == false

    TopicUser.change(@post.user_id,
                     @topic.id,
                     posted: true,
                     last_read_post_number: @post.post_number,
                     highest_seen_post_number: @post.post_number)


    PostTiming.record_timing(topic_id: @post.topic_id,
                             user_id: @post.user_id,
                             post_number: @post.post_number,
                             msecs: 5000)


    TopicUser.auto_track(@user.id, @topic.id, TopicUser.notification_reasons[:created_post])
  end

  def enqueue_jobs
    return unless @post && !@post.errors.present?
    PostJobsEnqueuer.new(@post, @topic, new_topic?, {import_mode: @opts[:import_mode]}).enqueue_jobs
  end

  def new_topic?
    @opts[:topic_id].blank?
  end

end
