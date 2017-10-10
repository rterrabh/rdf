
class ExportedUser < SecureUploader

  def store_dir
    "uploads/users"
  end

  def extension_white_list
    %w(gz)
  end

  def filename
    "#{model.username}_diaspora_data_#{secure_token}.json.gz"
  end

end
