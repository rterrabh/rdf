require_dependency 'topic_list'

class SuggestedTopicsBuilder

  attr_reader :excluded_topic_ids

  def initialize(topic)
    @excluded_topic_ids = [topic.id]
    @category_id = topic.category_id
    @category_topic_ids = Category.pluck(:topic_id).compact
    @results = []
  end


  def add_results(results, priority=:low)

    return unless results

    results = results.where('topics.id NOT IN (?)', @excluded_topic_ids)
                     .where(visible: true)

    if @category_id && SiteSetting.limit_suggested_to_category?
      results = results.where(category_id: @category_id)
    end

    results = results.to_a.reject { |topic| @category_topic_ids.include?(topic.id) }

    unless results.empty?
      @excluded_topic_ids.concat results.map {|r| r.id}
      splice_results(results,priority)
    end
  end

  def splice_results(results, priority)
    if  @category_id && priority == :high


      other_category_index = @results.index { |r| r.category_id != @category_id }
      category_results, other_category_results = results.partition{ |r| r.category_id == @category_id }

      if other_category_index
        @results.insert other_category_index, *category_results
      else
        @results.concat category_results
      end
      @results.concat other_category_results
    else
      @results.concat results
    end
  end

  def results
    @results.first(SiteSetting.suggested_topics)
  end

  def results_left
    SiteSetting.suggested_topics - @results.size
  end

  def full?
    results_left <= 0
  end

  def category_results_left
    SiteSetting.suggested_topics - @results.count{|r| r.category_id == @category_id}
  end

  def size
    @results.size
  end

end
