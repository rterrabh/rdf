class SecureUploader < CarrierWave::Uploader::Base
  protected
  def secure_token(bytes = 16)
    var = :"@#{mounted_as}_secure_token"
    #nodyna <instance_variable_get-228> <not yet classified>
    #nodyna <instance_variable_set-229> <not yet classified>
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.urlsafe_base64(bytes))
  end
end
