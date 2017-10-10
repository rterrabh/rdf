

module Workers
  class ProcessPhoto < Base
    sidekiq_options queue: :photos

    def perform(id)
      photo = Photo.find(id)
      unprocessed_image = photo.unprocessed_image

      return false if photo.processed? || unprocessed_image.path.try(:include?, ".gif")

      photo.processed_image.store!(unprocessed_image)

      photo.save!
    rescue ActiveRecord::RecordNotFound # Deleted before the job was run
    end
  end
end
