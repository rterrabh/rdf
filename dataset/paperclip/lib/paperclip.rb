
require 'erb'
require 'digest'
require 'tempfile'
require 'paperclip/version'
require 'paperclip/geometry_parser_factory'
require 'paperclip/geometry_detector_factory'
require 'paperclip/geometry'
require 'paperclip/processor'
require 'paperclip/processor_helpers'
require 'paperclip/tempfile'
require 'paperclip/thumbnail'
require 'paperclip/interpolations/plural_cache'
require 'paperclip/interpolations'
require 'paperclip/tempfile_factory'
require 'paperclip/style'
require 'paperclip/attachment'
require 'paperclip/storage'
require 'paperclip/callbacks'
require 'paperclip/file_command_content_type_detector'
require 'paperclip/media_type_spoof_detector'
require 'paperclip/content_type_detector'
require 'paperclip/glue'
require 'paperclip/errors'
require 'paperclip/missing_attachment_styles'
require 'paperclip/validators'
require 'paperclip/logger'
require 'paperclip/helpers'
require 'paperclip/has_attached_file'
require 'paperclip/attachment_registry'
require 'paperclip/filename_cleaner'
require 'paperclip/rails_environment'

begin
  require "mime/types/columnar"
rescue LoadError
  require "mime/types"
end

require 'mimemagic'
require 'mimemagic/overlay'
require 'logger'
require 'cocaine'

require 'paperclip/railtie' if defined?(Rails::Railtie)

module Paperclip
  extend Helpers
  extend Logger
  extend ProcessorHelpers

  def self.options
    @options ||= {
      :whiny => true,
      :image_magick_path => nil,
      :command_path => nil,
      :log => true,
      :log_command => true,
      :swallow_stderr => true,
      :content_type_mappings => {},
      :use_exif_orientation => true
    }
  end

  def self.io_adapters=(new_registry)
    @io_adapters = new_registry
  end

  def self.io_adapters
    @io_adapters ||= Paperclip::AdapterRegistry.new
  end

  module ClassMethods
    def has_attached_file(name, options = {})
      HasAttachedFile.define_on(self, name, options)
    end
  end
end

require 'paperclip/io_adapters/registry'
require 'paperclip/io_adapters/abstract_adapter'
require 'paperclip/io_adapters/empty_string_adapter'
require 'paperclip/io_adapters/identity_adapter'
require 'paperclip/io_adapters/file_adapter'
require 'paperclip/io_adapters/stringio_adapter'
require 'paperclip/io_adapters/data_uri_adapter'
require 'paperclip/io_adapters/nil_adapter'
require 'paperclip/io_adapters/attachment_adapter'
require 'paperclip/io_adapters/uploaded_file_adapter'
require 'paperclip/io_adapters/uri_adapter'
require 'paperclip/io_adapters/http_url_proxy_adapter'
