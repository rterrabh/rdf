$:.unshift File.dirname(__FILE__) # For use/testing when no gem is installed

def require_all(path)
  glob = File.join(File.dirname(__FILE__), path, '*.rb')
  Dir[glob].each do |f|
    require f
  end
end

require 'rubygems'

require 'fileutils'
require 'time'
require 'English'
require 'pathname'
require 'logger'
require 'set'

require 'safe_yaml/load'
require 'liquid'
require 'kramdown'
require 'colorator'

SafeYAML::OPTIONS[:suppress_warnings] = true
Liquid::Template.error_mode = :strict

module Jekyll

  autoload :Cleaner,             'jekyll/cleaner'
  autoload :Collection,          'jekyll/collection'
  autoload :Configuration,       'jekyll/configuration'
  autoload :Convertible,         'jekyll/convertible'
  autoload :Deprecator,          'jekyll/deprecator'
  autoload :Document,            'jekyll/document'
  autoload :Draft,               'jekyll/draft'
  autoload :EntryFilter,         'jekyll/entry_filter'
  autoload :Errors,              'jekyll/errors'
  autoload :Excerpt,             'jekyll/excerpt'
  autoload :External,            'jekyll/external'
  autoload :Filters,             'jekyll/filters'
  autoload :FrontmatterDefaults, 'jekyll/frontmatter_defaults'
  autoload :Hooks,               'jekyll/hooks'
  autoload :Layout,              'jekyll/layout'
  autoload :CollectionReader,    'jekyll/readers/collection_reader'
  autoload :DataReader,          'jekyll/readers/data_reader'
  autoload :LayoutReader,        'jekyll/readers/layout_reader'
  autoload :DraftReader,         'jekyll/readers/draft_reader'
  autoload :PostReader,          'jekyll/readers/post_reader'
  autoload :PageReader,          'jekyll/readers/page_reader'
  autoload :StaticFileReader,    'jekyll/readers/static_file_reader'
  autoload :LogAdapter,          'jekyll/log_adapter'
  autoload :Page,                'jekyll/page'
  autoload :PluginManager,       'jekyll/plugin_manager'
  autoload :Post,                'jekyll/post'
  autoload :Publisher,           'jekyll/publisher'
  autoload :Reader,              'jekyll/reader'
  autoload :Regenerator,         'jekyll/regenerator'
  autoload :RelatedPosts,        'jekyll/related_posts'
  autoload :Renderer,            'jekyll/renderer'
  autoload :LiquidRenderer,      'jekyll/liquid_renderer'
  autoload :Site,                'jekyll/site'
  autoload :StaticFile,          'jekyll/static_file'
  autoload :Stevenson,           'jekyll/stevenson'
  autoload :URL,                 'jekyll/url'
  autoload :Utils,               'jekyll/utils'
  autoload :VERSION,             'jekyll/version'

  require 'jekyll/plugin'
  require 'jekyll/converter'
  require 'jekyll/generator'
  require 'jekyll/command'
  require 'jekyll/liquid_extensions'

  class << self

    def env
      ENV["JEKYLL_ENV"] || "development"
    end

    def configuration(override = Hash.new)
      config = Configuration[Configuration::DEFAULTS]
      override = Configuration[override].stringify_keys
      unless override.delete('skip_config_files')
        config = config.read_config_files(config.config_files(override))
      end

      config = Utils.deep_merge_hashes(config, override).stringify_keys
      set_timezone(config['timezone']) if config['timezone']

      config
    end

    def set_timezone(timezone)
      ENV['TZ'] = timezone
    end

    def logger
      @logger ||= LogAdapter.new(Stevenson.new, (ENV["JEKYLL_LOG_LEVEL"] || :info).to_sym)
    end

    def logger=(writer)
      @logger = LogAdapter.new(writer)
    end

    def sites
      @sites ||= []
    end

    def sanitized_path(base_directory, questionable_path)
      return base_directory if base_directory.eql?(questionable_path)

      clean_path = File.expand_path(questionable_path, "/")
      clean_path = clean_path.sub(/\A\w\:\//, '/')

      unless clean_path.start_with?(base_directory.sub(/\A\w\:\//, '/'))
        File.join(base_directory, clean_path)
      else
        clean_path
      end
    end

    Jekyll::External.require_if_present('liquid-c')

  end
end

require_all 'jekyll/commands'
require_all 'jekyll/converters'
require_all 'jekyll/converters/markdown'
require_all 'jekyll/generators'
require_all 'jekyll/tags'

require 'jekyll-sass-converter'
