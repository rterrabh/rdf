

module Workers
  class FetchProfilePhoto < Base
    sidekiq_options queue: :photos

    def perform(user_id, service_id, fallback_image_url = nil)
      service = Service.find(service_id)

      image_url = service.profile_photo_url
      image_url ||= fallback_image_url

      return unless image_url

      user = User.find(user_id)

      @photo = Photo.diaspora_initialize(:author => user.person, :image_url => image_url, :pending => true)
      @photo.save!
      
      profile_params = {:image_url => @photo.url(:thumb_large),
                       :image_url_medium => @photo.url(:thumb_medium),
                       :image_url_small => @photo.url(:thumb_small)}
      user.update_profile(profile_params)
    end
  end
end
