class BasicTopicSerializer < ApplicationSerializer
  attributes :id, :title, :fancy_title, :slug, :posts_count
end
