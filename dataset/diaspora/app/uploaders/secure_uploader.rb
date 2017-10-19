class SecureUploader < CarrierWave::Uploader::Base
  protected
  def secure_token(bytes = 16)
    var = :"@#{mounted_as}_secure_token"
    #nodyna <instance_variable_get-228> <IVG COMPLEX (change-prone variable)>
    #nodyna <instance_variable_set-229> <IVS COMPLEX (change-prone variable)>
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.urlsafe_base64(bytes))
  end
end
