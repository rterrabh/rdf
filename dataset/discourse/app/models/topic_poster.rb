class TopicPoster < OpenStruct
  include ActiveModel::Serialization

  attr_accessor :user, :description, :extras, :id

  def attributes
    {
      'user' => user,
      'description' => description,
      'extras' => extras,
      'id' => id
    }
  end

  # TODO: Remove when old list is removed
  def [](attr)
    #nodyna <ID:send-213> <send VERY HIGH ex3>
    send(attr)
  end
end
