require_dependency 'search/grouped_search_results'

class Search

  def self.per_facet
    5
  end

  def self.per_filter
    50
  end

  def self.burst_factor
    3
  end

  def self.facets
    %w(topic category user private_messages)
  end

  def self.long_locale
    case SiteSetting.default_locale.to_sym
      when :da     then 'danish'
      when :de     then 'german'
      when :en     then 'english'
      when :es     then 'spanish'
      when :fr     then 'french'
      when :it     then 'italian'
      when :nl     then 'dutch'
      when :nb_NO  then 'norwegian'
      when :pt     then 'portuguese'
      when :pt_BR  then 'portuguese'
      when :sv     then 'swedish'
      when :ru     then 'russian'
      else 'simple' # use the 'simple' stemmer for other languages
    end
  end

  def self.rebuild_problem_posts(limit = 10000)
    posts = Post.joins(:topic)
            .where('posts.id IN (
               SELECT p2.id FROM posts p2
               LEFT JOIN post_search_data pd ON locale = ? AND p2.id = pd.post_id
               WHERE pd.post_id IS NULL
              )', SiteSetting.default_locale).limit(10000)

    posts.each do |post|
      post.cooked += " "
      SearchObserver.index(post)
    end

    posts = Post.joins(:topic)
            .where('posts.id IN (
               SELECT p2.id FROM posts p2
               LEFT JOIN topic_search_data pd ON locale = ? AND p2.topic_id = pd.topic_id
               WHERE pd.topic_id IS NULL AND p2.post_number = 1
              )', SiteSetting.default_locale).limit(10000)

    posts.each do |post|
      post.cooked += " "
      SearchObserver.index(post)
    end

    nil
  end

  def self.prepare_data(search_data)
    data = search_data.squish
    if ['zh_TW', 'zh_CN', 'ja', 'ko'].include?(SiteSetting.default_locale)
      unless defined? RMMSeg
        require 'rmmseg'
        RMMSeg::Dictionary.load_dictionaries
      end

      algo = RMMSeg::Algorithm.new(search_data)

      data = ""
      while token = algo.next_token
        data << token.text << " "
      end
    end

    data.force_encoding("UTF-8")
    data
  end

  def initialize(term, opts=nil)
    @opts = opts || {}
    @guardian = @opts[:guardian] || Guardian.new
    @search_context = @opts[:search_context]
    @include_blurbs = @opts[:include_blurbs] || false
    @blurb_length = @opts[:blurb_length]
    @limit = Search.per_facet

    term = process_advanced_search!(term)
    if term.present?
      @term = Search.prepare_data(term.to_s)
      @original_term = PG::Connection.escape_string(@term)
    end

    if @search_pms && @guardian.user
      @opts[:type_filter] = "private_messages"
      @search_context = @guardian.user
    end

    if @opts[:type_filter].present?
      @limit = Search.per_filter
    end

    @results = GroupedSearchResults.new(@opts[:type_filter], term, @search_context, @include_blurbs, @blurb_length)
  end

  def self.execute(term, opts=nil)
    self.new(term, opts).execute
  end

  def execute
    if @term.blank? || @term.length < (@opts[:min_search_term_length] || SiteSetting.min_search_term_length)
      return nil unless @filters.present?
    end

    if @opts[:search_for_id] && @results.type_filter == 'topic'
      if @term =~ /^\d+$/
        single_topic(@term.to_i)
      else
        begin
          route = Rails.application.routes.recognize_path(@term)
          single_topic(route[:topic_id]) if route[:topic_id].present?
        rescue ActionController::RoutingError
        end
      end
    end

    find_grouped_results unless @results.posts.present?

    @results
  end

  def self.advanced_filter(trigger,&block)
    (@advanced_filters ||= {})[trigger] = block
  end

  def self.advanced_filters
    @advanced_filters
  end

  advanced_filter(/status:open/) do |posts|
    posts.where('NOT topics.closed AND NOT topics.archived')
  end

  advanced_filter(/status:closed/) do |posts|
    posts.where('topics.closed')
  end

  advanced_filter(/status:archived/) do |posts|
    posts.where('topics.archived')
  end

  advanced_filter(/status:noreplies/) do |posts|
    posts.where("topics.posts_count = 1")
  end

  advanced_filter(/status:single_user/) do |posts|
    posts.where("topics.participant_count = 1")
  end

  advanced_filter(/posts_count:(\d+)/) do |posts, match|
    posts.where("topics.posts_count = ?", match.to_i)
  end

  advanced_filter(/in:first/) do |posts|
    posts.where("posts.post_number = 1")
  end

  advanced_filter(/in:(likes|bookmarks)/) do |posts, match|
    if @guardian.user
      post_action_type = PostActionType.types[:like] if match == "likes"
      post_action_type = PostActionType.types[:bookmark] if match == "bookmarks"

      posts.where("posts.id IN (
                            SELECT pa.post_id FROM post_actions pa
                            WHERE pa.user_id = #{@guardian.user.id} AND
                                  pa.post_action_type_id = #{post_action_type} AND
                                  deleted_at IS NULL
                         )")
    end
  end

  advanced_filter(/in:posted/) do |posts|
    posts.where("posts.user_id = #{@guardian.user.id}") if @guardian.user
  end

  advanced_filter(/in:(watching|tracking)/) do |posts,match|
    if @guardian.user
      level = TopicUser.notification_levels[match.to_sym]
      posts.where("posts.topic_id IN (
                    SELECT tu.topic_id FROM topic_users tu
                    WHERE tu.user_id = #{@guardian.user.id} AND
                          tu.notification_level >= #{level}
                   )")

    end
  end

  advanced_filter(/category:(.+)/) do |posts,match|
    category_id = Category.where('name ilike ? OR id = ?', match, match.to_i).pluck(:id).first
    if category_id
      posts.where("topics.category_id = ?", category_id)
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/user:(.+)/) do |posts,match|
    user_id = User.where('username_lower = ? OR id = ?', match.downcase, match.to_i).pluck(:id).first
    if user_id
      posts.where("posts.user_id = #{user_id}")
    else
      posts.where("1 = 0")
    end
  end

  advanced_filter(/min_age:(\d+)/) do |posts,match|
    n = match.to_i
    posts.where("topics.created_at > ?", n.days.ago)
  end

  advanced_filter(/max_age:(\d+)/) do |posts,match|
    n = match.to_i
    posts.where("topics.created_at < ?", n.days.ago)
  end

  private


    def process_advanced_search!(term)

      term.to_s.split(/\s+/).map do |word|

        found = false

        Search.advanced_filters.each do |matcher, block|
          if word =~ matcher
            (@filters ||= []) << [block, $1]
            found = true
          end
        end

        if word == 'order:latest'
          @order = :latest
          nil
        elsif word =~ /topic:(\d+)/
          topic_id = $1.to_i
          if topic_id > 1
            topic = Topic.find_by(id: topic_id)
            if @guardian.can_see?(topic)
              @search_context = topic
            end
          end
          nil
        elsif word == 'order:views'
          @order = :views
          nil
        elsif word == 'in:private'
          @search_pms = true
          nil
        else
          found ? nil : word
        end
      end.compact.join(' ')
    end


    def find_grouped_results

      if @results.type_filter.present?
        raise Discourse::InvalidAccess.new("invalid type filter") unless Search.facets.include?(@results.type_filter)
        #nodyna <send-342> <SD COMPLEX (change-prone variables)>
        send("#{@results.type_filter}_search")
      else
        @limit = Search.per_facet + 1
        unless @search_context
          user_search if @term.present?
          category_search if @term.present?
        end
        topic_search
      end

      add_more_topics_if_expected
      @results
    rescue ActiveRecord::StatementInvalid
    end

    def add_more_topics_if_expected
      expected_topics = 0
      expected_topics = Search.facets.size unless @results.type_filter.present?
      expected_topics = Search.per_facet * Search.facets.size if @results.type_filter == 'topic'
      expected_topics -= @results.posts.length
      if expected_topics > 0
        extra_posts = posts_query(expected_topics * Search.burst_factor)
        extra_posts = extra_posts.where("posts.topic_id NOT in (?)", @results.posts.map(&:topic_id)) if @results.posts.present?
        extra_posts.each do |post|
          @results.add(post)
          expected_topics -= 1
          break if expected_topics == 0
        end
      end
    end

    def single_topic(id)
      post = Post.find_by(topic_id: id, post_number: 1)
      return nil unless @guardian.can_see?(post)

      @results.add(post)
      @results
    end

    def secure_category_ids
      return @secure_category_ids unless @secure_category_ids.nil?
      @secure_category_ids = @guardian.secure_category_ids
    end

    def category_search
      secure_category_ids

      categories = Category.includes(:category_search_data)
                           .where("category_search_data.search_data @@ #{ts_query}")
                           .references(:category_search_data)
                           .order("topics_month DESC")
                           .secured(@guardian)
                           .limit(@limit)

      categories.each do |category|
        @results.add(category)
      end
    end

    def user_search
      users = User.includes(:user_search_data)
                  .where("active = true AND user_search_data.search_data @@ #{ts_query("simple")}")
                  .order("CASE WHEN username_lower = '#{@original_term.downcase}' THEN 0 ELSE 1 END")
                  .order("last_posted_at DESC")
                  .limit(@limit)
                  .references(:user_search_data)

      users.each do |user|
        @results.add(user)
      end
    end

    def posts_query(limit, opts=nil)
      opts ||= {}
      posts = Post
                  .joins(:post_search_data, :topic)
                  .joins("LEFT JOIN categories ON categories.id = topics.category_id")
                  .where("topics.deleted_at" => nil)
                  .where("topics.visible")

      is_topic_search = @search_context.present? && @search_context.is_a?(Topic)

      if opts[:private_messages] || (is_topic_search && @search_context.private_message?)
         posts = posts.where("topics.archetype =  ?", Archetype.private_message)

         unless @guardian.is_admin?
            posts = posts.where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)", @guardian.user.id)
         end
      else
         posts = posts.where("topics.archetype <> ?", Archetype.private_message)
      end

      if @term.present?
        if is_topic_search
          posts = posts.joins('JOIN users u ON u.id = posts.user_id')
          posts = posts.where("posts.raw  || ' ' || u.username || ' ' || u.name ilike ?", "%#{@term}%")
        else
          posts = posts.where("post_search_data.search_data @@ #{ts_query}")
          exact_terms = @term.scan(/"([^"]+)"/).flatten
          exact_terms.each do |exact|
            posts = posts.where("posts.raw ilike ?", "%#{exact}%")
          end
        end
      end

      @filters.each do |block, match|
        if block.arity == 1
          #nodyna <instance_exec-343> <IEX COMPLEX (block with parameters)>
          posts = instance_exec(posts, &block) || posts
        else
          #nodyna <instance_exec-344> <IEX COMPLEX (block with parameters)>
          posts = instance_exec(posts, match, &block) || posts
        end
      end if @filters

      if @search_context.present?

        if @search_context.is_a?(User)

          if opts[:private_messages]
            posts = posts.where("topics.id IN (SELECT topic_id FROM topic_allowed_users WHERE user_id = ?)", @search_context.id)
          else
            posts = posts.where("posts.user_id = #{@search_context.id}")
          end

        elsif @search_context.is_a?(Category)
          posts = posts.where("topics.category_id = #{@search_context.id}")
        elsif @search_context.is_a?(Topic)
          posts = posts.where("topics.id = #{@search_context.id}")
                       .order("posts.post_number")
        end

      end

      if @order == :latest || @term.blank?
        if opts[:aggregate_search]
          posts = posts.order("MAX(posts.created_at) DESC")
        else
          posts = posts.order("posts.created_at DESC")
        end
      elsif @order == :views
        if opts[:aggregate_search]
          posts = posts.order("MAX(topics.views) DESC")
        else
          posts = posts.order("topics.views DESC")
        end
      else
        posts = posts.order("TS_RANK_CD(TO_TSVECTOR(#{query_locale}, topics.title), #{ts_query}) DESC")

        data_ranking = "TS_RANK_CD(post_search_data.search_data, #{ts_query})"
        if opts[:aggregate_search]
          posts = posts.order("SUM(#{data_ranking}) DESC")
        else
          posts = posts.order("#{data_ranking} DESC")
        end
        posts = posts.order("topics.bumped_at DESC")
      end

      if secure_category_ids.present?
        posts = posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted) OR (categories.id IN (?))", secure_category_ids).references(:categories)
      else
        posts = posts.where("(categories.id IS NULL) OR (NOT categories.read_restricted)").references(:categories)
      end
      posts.limit(limit)
    end

    def self.query_locale
      @query_locale ||= Post.sanitize(Search.long_locale)
    end

    def query_locale
      self.class.query_locale
    end

    def self.ts_query(term, locale = nil, joiner = "&")

      data = Post.exec_sql("SELECT to_tsvector(:locale, :term)",
                            locale: locale || long_locale,
                            term: term
                          ).values[0][0]

      locale = Post.sanitize(locale) if locale
      all_terms = data.scan(/'([^']+)'\:\d+/).flatten
      all_terms.map! do |t|
        t.split(/[\)\(&']/)[0]
      end.compact!

      query = Post.sanitize(all_terms.map {|t| "'#{PG::Connection.escape_string(t)}':*"}.join(" #{joiner} "))
      "TO_TSQUERY(#{locale || query_locale}, #{query})"
    end

    def ts_query(locale=nil)
      @ts_query_cache ||= {}
      @ts_query_cache[(locale || query_locale) + " " + @term] ||= Search.ts_query(@term, locale)
    end

    def aggregate_search(opts = {})

      post_sql = posts_query(@limit, aggregate_search: true,
                                     private_messages: opts[:private_messages])
        .select('topics.id', 'min(post_number) post_number')
        .group('topics.id')
        .to_sql

      post_sql = "SELECT *, row_number() over() row_number FROM (#{post_sql}) xxx"

      posts = Post.includes(:topic => :category)
                  .joins("JOIN (#{post_sql}) x ON x.id = posts.topic_id AND x.post_number = posts.post_number")
                  .order('row_number')

      posts.each do |post|
        @results.add(post)
      end
    end

    def private_messages_search
      raise Discourse::InvalidAccess.new("anonymous can not search PMs") unless @guardian.user

      aggregate_search(private_messages: true)
    end

    def topic_search
      if @search_context.is_a?(Topic)
        posts = posts_query(@limit).where('posts.topic_id = ?', @search_context.id).includes(:topic => :category)
        posts.each do |post|
          @results.add(post)
        end
      else
        aggregate_search
      end
    end

end
