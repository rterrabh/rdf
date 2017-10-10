module Jobs

  class FeatureTopicUsers < Jobs::Base

    def execute(args)
      topic_id = args[:topic_id]
      raise Discourse::InvalidParameters.new(:topic_id) unless topic_id.present?

      topic = Topic.find_by(id: topic_id)

      return unless topic.present?

      topic.feature_topic_users(args)
    end

  end

end
