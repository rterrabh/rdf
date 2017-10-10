
class Stream::Aspect < Stream::Base

  def initialize(user, inputted_aspect_ids, opts={})
    super(user, opts)
    @inputted_aspect_ids = inputted_aspect_ids
  end

  def aspects
    @aspects ||= lambda do
      a = user.aspects
      a = a.where(:id => @inputted_aspect_ids) if @inputted_aspect_ids.any?
      a
    end.call
  end

  def aspect_ids
    @aspect_ids ||= aspects.map { |a| a.id }
  end

  def posts
    @posts ||= user.visible_shareables(Post, :all_aspects? => for_all_aspects?,
                                             :by_members_of => aspect_ids,
                                             :type => TYPES_OF_POST_IN_STREAM,
                                             :order => "#{order} DESC",
                                             :max_time => max_time
                   )
  end

  def people
    @people ||= Person.unique_from_aspects(aspect_ids, user).includes(:profile)
  end

  def link(opts={})
    Rails.application.routes.url_helpers.aspects_path(opts)
  end

  def aspect
    if !for_all_aspects? || aspects.size == 1
      aspects.first
    end
  end

  def title
    if self.for_all_aspects?
      I18n.t('streams.aspects.title')
    else
      self.aspects.to_sentence
    end
  end

  def for_all_aspects?
    @all_aspects ||= aspect_ids.length == user.aspects.size
  end

  def contacts_title
    if self.for_all_aspects? || self.aspect_ids.size > 1
      I18n.t('_contacts')
    else
     "#{self.aspect.name} (#{self.people.size})"
    end
  end

  def contacts_link
    if for_all_aspects? || aspect_ids.size > 1
      Rails.application.routes.url_helpers.contacts_path
    else
      Rails.application.routes.url_helpers.contacts_path(:a_id => aspect.id)
    end
  end

  def can_comment?(post)
    true
  end
end
