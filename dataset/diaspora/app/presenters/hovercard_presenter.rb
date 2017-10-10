class HovercardPresenter

  attr_accessor :person

  def initialize(person)
    raise ArgumentError, "the given object is not a Person" unless person.class == Person

    self.person = person
  end

  def to_json(options={})
    {  :id => person.id,
       :avatar => avatar('medium'),
       :url => profile_url,
       :name => person.name,
       :handle => person.diaspora_handle,
       :tags => person.tags.map { |t| "#"+t.name }
    }.to_json(options)
  end

  def avatar(size="medium")
    if !["small", "medium", "large"].include?(size)
      raise ArgumentError, "the given parameter is not a valid size"
    end

    person.image_url("thumb_#{size}".to_sym)
  end

  def profile_url
    Rails.application.routes.url_helpers.person_path(person)
  end
end
