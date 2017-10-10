require_dependency 'pinned_check'

class CategoryList
  include ActiveModel::Serialization

  attr_accessor :categories,
                :topic_users,
                :uncategorized,
                :draft,
                :draft_key,
                :draft_sequence

  def initialize(guardian=nil, options = {})
    @guardian = guardian || Guardian.new
    @options = options

    find_relevant_topics unless latest_post_only?
    find_categories

    prune_empty
    find_user_data
    sort_unpinned
    trim_results
  end

  private

    def latest_post_only?
      @options[:latest_posts] and latest_posts_count == 1
    end

    def include_latest_posts?
      @options[:latest_posts] and latest_posts_count > 1
    end

    def latest_posts_count
      @options[:latest_posts].to_i > 0 ? @options[:latest_posts].to_i : SiteSetting.category_featured_topics
    end

    def find_relevant_topics
      @topics_by_category_id = {}
      category_featured_topics = CategoryFeaturedTopic.select([:category_id, :topic_id]).order(:rank)
      @topics_by_id = {}

      @all_topics = Topic.where(id: category_featured_topics.map(&:topic_id))
      @all_topics = @all_topics.includes(:last_poster) if include_latest_posts?
      @all_topics.each do |t|
        t.include_last_poster = true if include_latest_posts? # hint for serialization
        @topics_by_id[t.id] = t
      end

      category_featured_topics.each do |cft|
        @topics_by_category_id[cft.category_id] ||= []
        @topics_by_category_id[cft.category_id] << cft.topic_id
      end
    end

    def find_categories
      @categories = Category
                        .includes(:featured_users, :topic_only_relative_url, subcategories: [:topic_only_relative_url])
                        .secured(@guardian)

      if @options[:parent_category_id].present?
        @categories = @categories.where('categories.parent_category_id = ?', @options[:parent_category_id].to_i)
      end

      if SiteSetting.fixed_category_positions
        @categories = @categories.order('position ASC').order('id ASC')
      else
        @categories = @categories.order('COALESCE(categories.posts_week, 0) DESC')
                                 .order('COALESCE(categories.posts_month, 0) DESC')
                                 .order('COALESCE(categories.posts_year, 0) DESC')
                                 .order('id ASC')
      end

      if latest_post_only?
        @categories  = @categories.includes(:latest_post => {:topic => :last_poster} )
      end

      @categories = @categories.to_a
      if @options[:parent_category_id].blank?
        subcategories = {}
        to_delete = Set.new
        @categories.each do |c|
          if c.parent_category_id.present?
            subcategories[c.parent_category_id] ||= []
            subcategories[c.parent_category_id] << c.id
            to_delete << c
          end
        end

        if subcategories.present?
          @categories.each do |c|
            c.subcategory_ids = subcategories[c.id]
          end
          @categories.delete_if {|c| to_delete.include?(c) }
        end
      end

      if latest_post_only?
        @all_topics = []
        @categories.each do |c|
          if c.latest_post && c.latest_post.topic && @guardian.can_see?(c.latest_post.topic)
            c.displayable_topics = [c.latest_post.topic]
            topic = c.latest_post.topic
            topic.include_last_poster = true # hint for serialization
            @all_topics << topic
          end
        end
      end

      if @topics_by_category_id
        @categories.each do |c|
          topics_in_cat = @topics_by_category_id[c.id]
          if topics_in_cat.present?
            c.displayable_topics = []
            topics_in_cat.each do |topic_id|
              topic = @topics_by_id[topic_id]
              if topic.present? && @guardian.can_see?(topic)
                topic.association(:category).target = c
                c.displayable_topics << topic
              end
            end
          end
        end
      end
    end


    def prune_empty
      if !@guardian.can_create?(Category)
        @categories.delete_if do |c|
          c.displayable_topics.blank? && c.description.blank?
        end
      elsif !SiteSetting.allow_uncategorized_topics
        @categories.delete_if do |c|
          c.uncategorized? && c.displayable_topics.blank?
        end
      end
    end

    def find_user_data
      if @guardian.current_user && @all_topics.present?
        topic_lookup = TopicUser.lookup_for(@guardian.current_user, @all_topics)

        @all_topics.each { |ft| ft.user_data = topic_lookup[ft.id] }
      end
    end

    def sort_unpinned
      if @guardian.current_user && @all_topics.present?
        @categories.each do |c|
          next if c.displayable_topics.blank? || c.displayable_topics.size <= latest_posts_count
          unpinned = []
          c.displayable_topics.each do |t|
            unpinned << t if t.pinned_at && PinnedCheck.unpinned?(t, t.user_data)
          end
          unless unpinned.empty?
            c.displayable_topics = (c.displayable_topics - unpinned) + unpinned
          end
        end
      end
    end

    def trim_results
      @categories.each do |c|
        next if c.displayable_topics.blank?
        c.displayable_topics = c.displayable_topics[0,latest_posts_count]
      end
    end
end
