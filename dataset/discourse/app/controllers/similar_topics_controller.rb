require_dependency 'similar_topic_serializer'
require_dependency 'search/grouped_search_results'

class SimilarTopicsController < ApplicationController

  class SimilarTopic
    def initialize(topic)
      @topic = topic
    end

    attr_reader :topic

    def blurb
      Search::GroupedSearchResults.blurb_for(@topic.try(:blurb))
    end
  end

  def index
    params.require(:title)
    params.require(:raw)
    title, raw = params[:title], params[:raw]
    [:title, :raw].each { |key| check_length_of(key, params[key]) }

    return render json: [] unless Topic.count_exceeds_minimum?

    topics = Topic.similar_to(title, raw, current_user).to_a
    topics.map! {|t| SimilarTopic.new(t) }
    render_serialized(topics, SimilarTopicSerializer, root: :similar_topics, rest_serializer: true)
  end

  protected

    def check_length_of(key, attr)
      str = (key == :raw) ? "body" : key.to_s
      #nodyna <send-454> <SD COMPLEX (change-prone variables)>
      raise Discourse::InvalidParameters.new(key) if attr.length < SiteSetting.send("min_#{str}_similar_length")
    end

end
