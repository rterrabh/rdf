
require 'active_support'
require 'active_support/rails'
require 'action_view/version'

module ActionView
  extend ActiveSupport::Autoload

  ENCODING_FLAG = '#.*coding[:=]\s*(\S+)[ \t]*'

  eager_autoload do
    autoload :Base
    autoload :Context
    autoload :CompiledTemplates, "action_view/context"
    autoload :Digestor
    autoload :Helpers
    autoload :LookupContext
    autoload :Layouts
    autoload :PathSet
    autoload :RecordIdentifier
    autoload :Rendering
    autoload :RoutingUrlFor
    autoload :Template
    autoload :ViewPaths

    autoload_under "renderer" do
      autoload :Renderer
      autoload :AbstractRenderer
      autoload :PartialRenderer
      autoload :TemplateRenderer
      autoload :StreamingTemplateRenderer
    end

    autoload_at "action_view/template/resolver" do
      autoload :Resolver
      autoload :PathResolver
      autoload :OptimizedFileSystemResolver
      autoload :FallbackFileSystemResolver
    end

    autoload_at "action_view/buffers" do
      autoload :OutputBuffer
      autoload :StreamingBuffer
    end

    autoload_at "action_view/flows" do
      autoload :OutputFlow
      autoload :StreamingFlow
    end

    autoload_at "action_view/template/error" do
      autoload :MissingTemplate
      autoload :ActionViewError
      autoload :EncodingError
      autoload :MissingRequestError
      autoload :TemplateError
      autoload :WrongEncodingError
    end
  end

  autoload :TestCase

  def self.eager_load!
    super
    ActionView::Helpers.eager_load!
    ActionView::Template.eager_load!
  end
end

require 'active_support/core_ext/string/output_safety'

ActiveSupport.on_load(:i18n) do
  I18n.load_path << "#{File.dirname(__FILE__)}/action_view/locale/en.yml"
end
