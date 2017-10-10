
class Stream::Person < Stream::Base

  attr_accessor :person

  def initialize(user, person, opts={})
    self.person = person
    super(user, opts)
  end

  def posts
    @posts ||= user.present? ? user.posts_from(@person) : @person.posts.where(:public => true)
  end
end
