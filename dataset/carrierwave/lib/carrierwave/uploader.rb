
require "carrierwave/uploader/configuration"
require "carrierwave/uploader/callbacks"
require "carrierwave/uploader/proxy"
require "carrierwave/uploader/url"
require "carrierwave/uploader/mountable"
require "carrierwave/uploader/cache"
require "carrierwave/uploader/store"
require "carrierwave/uploader/download"
require "carrierwave/uploader/remove"
require "carrierwave/uploader/extension_whitelist"
require "carrierwave/uploader/extension_blacklist"
require "carrierwave/uploader/processing"
require "carrierwave/uploader/versions"
require "carrierwave/uploader/default_url"

require "carrierwave/uploader/serialization"

module CarrierWave

  module Uploader

    class Base
      attr_reader :file

      include CarrierWave::Uploader::Configuration
      include CarrierWave::Uploader::Callbacks
      include CarrierWave::Uploader::Proxy
      include CarrierWave::Uploader::Url
      include CarrierWave::Uploader::Mountable
      include CarrierWave::Uploader::Cache
      include CarrierWave::Uploader::Store
      include CarrierWave::Uploader::Download
      include CarrierWave::Uploader::Remove
      include CarrierWave::Uploader::ExtensionWhitelist
      include CarrierWave::Uploader::ExtensionBlacklist
      include CarrierWave::Uploader::Processing
      include CarrierWave::Uploader::Versions
      include CarrierWave::Uploader::DefaultUrl
      include CarrierWave::Uploader::Serialization
    end # Base

  end # Uploader
end # CarrierWave
