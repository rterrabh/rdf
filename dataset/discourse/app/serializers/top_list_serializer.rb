class TopListSerializer < ApplicationSerializer

  attributes :can_create_topic,
             :draft,
             :draft_key,
             :draft_sequence

  def can_create_topic
    scope.can_create?(Topic)
  end

  TopTopic.periods.each do |period|
    attribute period

    #nodyna <ID:define_method-25> <define_method MEDIUM ex1>
    define_method(period) do
      #nodyna <ID:send-127> <send MEDIUM ex3>
      #nodyna <ID:send-127> <send MEDIUM ex3>
      TopicListSerializer.new(object.send(period), scope: scope).as_json if object.send(period)
    end

  end

end
