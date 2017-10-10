
class ExportedPhotos < SecureUploader

  def store_dir
    "uploads/users"
  end

  def filename
    "#{model.username}_photos_#{secure_token}.zip" if original_filename.present?
  end



end
