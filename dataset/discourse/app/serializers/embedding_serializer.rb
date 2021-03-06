class EmbeddingSerializer < ApplicationSerializer
  attributes :id, :fields, :base_url
  attributes *Embedding.settings

  has_many :embeddable_hosts, serializer: EmbeddableHostSerializer, embed: :ids

  def fields
    Embedding.settings
  end

  def read_attribute_for_serialization(attr)
    #nodyna <send-466> <SD COMPLEX (change-prone variables)>
    #nodyna <send-467> <SD COMPLEX (change-prone variables)>
    object.respond_to?(attr) ? object.send(attr) : send(attr)
  end
end
