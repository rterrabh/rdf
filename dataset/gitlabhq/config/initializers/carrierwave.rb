CarrierWave::SanitizedFile.sanitize_regexp = /[^[:word:]\.\-\+]/

aws_file = Rails.root.join('config', 'aws.yml')

if File.exists?(aws_file)
  AWS_CONFIG = YAML.load(File.read(aws_file))[Rails.env]

  CarrierWave.configure do |config|
    config.fog_credentials = {
      provider: 'AWS',                                        # required
      aws_access_key_id: AWS_CONFIG['access_key_id'],         # required
      aws_secret_access_key: AWS_CONFIG['secret_access_key'], # required
      region: AWS_CONFIG['region'],                           # optional, defaults to 'us-east-1'
    }

    config.fog_directory = AWS_CONFIG['bucket']

    config.fog_public = false

    config.fog_attributes = { 'Cache-Control'=>'max-age=315576000' }

    config.fog_authenticated_url_expiration = 1 << 29
  end

  if Rails.env.test?
    Fog.mock!
    connection = ::Fog::Storage.new(
        aws_access_key_id: AWS_CONFIG['access_key_id'],
        aws_secret_access_key: AWS_CONFIG['secret_access_key'],
        provider: 'AWS',
        region: AWS_CONFIG['region']
      )
    connection.directories.create(key: AWS_CONFIG['bucket'])
  end
end
