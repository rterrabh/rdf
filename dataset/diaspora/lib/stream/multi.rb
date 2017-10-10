class Stream::Multi < Stream::Base

  def link(opts)
    Rails.application.routes.url_helpers.stream_path(opts)
  end

  def title
    I18n.t('streams.multi.title')
  end

  def contacts_title
    I18n.t('streams.multi.contacts_title')
  end

  def posts
    @posts ||= ::EvilQuery::MultiStream.new(user, order, max_time, include_community_spotlight?).make_relation!
  end

  def post_from_group(post)
    streams_included.collect do |source|
      is_in?(source, post)
    end.compact
  end

  private
  def publisher_opts
    if welcome?
      {:open => true, :prefill => publisher_prefill, :public => true}
    else
      super
    end
  end

  def publisher_prefill
    prefill = I18n.t("shared.publisher.new_user_prefill.hello", :new_user_tag => I18n.t('shared.publisher.new_user_prefill.newhere'))
    if self.user.followed_tags.size > 0
      tag_string = self.user.followed_tags.map{|t| "##{t.name}"}.to_sentence
      prefill << I18n.t("shared.publisher.new_user_prefill.i_like", :tags => tag_string)
    end

    if inviter = self.user.invited_by.try(:person)
      prefill << I18n.t("shared.publisher.new_user_prefill.invited_by")
      prefill << "@{#{inviter.name} ; #{inviter.diaspora_handle}}!"
    end

    prefill
  end

  def welcome?
    self.user.getting_started
  end

  def streams_included
    @streams_included ||= lambda do
      array = [:mentioned, :aspects, :followed_tags]
      array << :community_spotlight if include_community_spotlight?
      array
    end.call
  end

  def is_in?(sym, post)
    #nodyna <send-222> <SD COMPLEX (change-prone variables)>
    if self.send("#{sym.to_s}_post_ids").find{|x| (x == post.id) || (x.to_s == post.id.to_s)}
      "#{sym.to_s}_stream".to_sym
    end
  end

  def include_community_spotlight?
    AppConfig.settings.community_spotlight.enable? && user.show_community_spotlight_in_stream?
  end
end
