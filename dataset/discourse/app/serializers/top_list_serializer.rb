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

    #nodyna <ID:define_method-25> <DM MODERATE (array)>
    define_method(period) do
      #nodyna <ID:send-127> <SD MODERATE (change-prone variables)>
      #nodyna <ID:send-127> <SD MODERATE (change-prone variables)>
      TopicListSerializer.new(object.send(period), scope: scope).as_json if object.send(period)
    end

  end

end
