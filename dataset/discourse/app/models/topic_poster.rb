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

  def [](attr)
    #nodyna <send-373> <SD COMPLEX (change-prone variables)>
    send(attr)
  end
end
