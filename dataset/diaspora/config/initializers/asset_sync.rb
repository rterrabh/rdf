if defined? AssetSync
  AssetSync.configure do |config|
    config.enabled = true
    
    config.fog_provider = 'AWS'
    config.aws_access_key_id = AppConfig.environment.s3.key.get
    config.aws_secret_access_key = AppConfig.environment.s3.secret.get
    config.fog_directory = AppConfig.environment.s3.bucket.get
  
    config.fog_region = AppConfig.environment.s3.region.get
  end
end
