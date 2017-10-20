require 'thread_safe'
require 'active_support/core_ext/module/remove_method'
require 'active_support/core_ext/module/attribute_accessors'
require 'action_view/template/resolver'

module ActionView
  class LookupContext #:nodoc:
    attr_accessor :prefixes, :rendered_format

    mattr_accessor :fallbacks
    @@fallbacks = FallbackFileSystemResolver.instances

    mattr_accessor :registered_details
    self.registered_details = []

    def self.register_detail(name, options = {}, &block)
      self.registered_details << name
      initialize = registered_details.map { |n| "@details[:#{n}] = details[:#{n}] || default_#{n}" }

      #nodyna <send-1192> <SD MODERATE (private methods)>
      #nodyna <define_method-1193> <DM MODERATE (events)>
      Accessors.send :define_method, :"default_#{name}", &block
      #nodyna <module_eval-1194> <ME MODERATE (define methods)>
      Accessors.module_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{name}
          @details.fetch(:#{name}, [])
        end

        def #{name}=(value)
          value = value.present? ? Array(value) : default_#{name}
          _set_detail(:#{name}, value) if value != @details[:#{name}]
        end

        remove_possible_method :initialize_details
        def initialize_details(details)
        end
      METHOD
    end

    module Accessors #:nodoc:
    end

    register_detail(:locale) do
      locales = [I18n.locale]
      locales.concat(I18n.fallbacks[I18n.locale]) if I18n.respond_to? :fallbacks
      locales << I18n.default_locale
      locales.uniq!
      locales
    end
    register_detail(:formats) { ActionView::Base.default_formats || [:html, :text, :js, :css,  :xml, :json] }
    register_detail(:variants) { [] }
    register_detail(:handlers){ Template::Handlers.extensions }

    class DetailsKey #:nodoc:
      alias :eql? :equal?
      alias :object_hash :hash

      attr_reader :hash
      @details_keys = ThreadSafe::Cache.new

      def self.get(details)
        if details[:formats]
          details = details.dup
          details[:formats] &= Mime::SET.symbols
        end
        @details_keys[details] ||= new
      end

      def self.clear
        @details_keys.clear
      end

      def initialize
        @hash = object_hash
      end
    end

    module DetailsCache
      attr_accessor :cache

      def details_key #:nodoc:
        @details_key ||= DetailsKey.get(@details) if @cache
      end

      def disable_cache
        old_value, @cache = @cache, false
        yield
      ensure
        @cache = old_value
      end

    protected

      def _set_detail(key, value)
        @details = @details.dup if @details_key
        @details_key = nil
        @details[key] = value
      end
    end

    module ViewPaths
      attr_reader :view_paths, :html_fallback_for_js

      def view_paths=(paths)
        @view_paths = ActionView::PathSet.new(Array(paths))
      end

      def find(name, prefixes = [], partial = false, keys = [], options = {})
        @view_paths.find(*args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias :find_template :find

      def find_all(name, prefixes = [], partial = false, keys = [], options = {})
        @view_paths.find_all(*args_for_lookup(name, prefixes, partial, keys, options))
      end

      def exists?(name, prefixes = [], partial = false, keys = [], options = {})
        @view_paths.exists?(*args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias :template_exists? :exists?

      def with_fallbacks
        added_resolvers = 0
        self.class.fallbacks.each do |resolver|
          next if view_paths.include?(resolver)
          view_paths.push(resolver)
          added_resolvers += 1
        end
        yield
      ensure
        added_resolvers.times { view_paths.pop }
      end

    protected

      def args_for_lookup(name, prefixes, partial, keys, details_options) #:nodoc:
        name, prefixes = normalize_name(name, prefixes)
        details, details_key = detail_args_for(details_options)
        [name, prefixes, partial || false, details, details_key, keys]
      end

      def detail_args_for(options)
        return @details, details_key if options.empty? # most common path.
        user_details = @details.merge(options)

        if @cache
          details_key = DetailsKey.get(user_details)
        else
          details_key = nil
        end

        [user_details, details_key]
      end

      def normalize_name(name, prefixes) #:nodoc:
        prefixes = prefixes.presence
        parts    = name.to_s.split('/')
        parts.shift if parts.first.empty?
        name     = parts.pop

        return name, prefixes || [""] if parts.empty?

        parts    = parts.join('/')
        prefixes = prefixes ? prefixes.map { |p| "#{p}/#{parts}" } : [parts]

        return name, prefixes
      end
    end

    include Accessors
    include DetailsCache
    include ViewPaths

    def initialize(view_paths, details = {}, prefixes = [])
      @details, @details_key = {}, nil
      @skip_default_locale = false
      @cache = true
      @prefixes = prefixes
      @rendered_format = nil

      self.view_paths = view_paths
      initialize_details(details)
    end

    def formats=(values)
      if values
        values.concat(default_formats) if values.delete "*/*"
        if values == [:js]
          values << :html
          @html_fallback_for_js = true
        end
      end
      super(values)
    end

    def skip_default_locale!
      @skip_default_locale = true
      self.locale = nil
    end

    def locale
      @details[:locale].first
    end

    def locale=(value)
      if value
        config = I18n.config.respond_to?(:original_config) ? I18n.config.original_config : I18n.config
        config.locale = value
      end

      super(@skip_default_locale ? I18n.locale : default_locale)
    end

    def with_layout_format
      if formats.size == 1
        yield
      else
        old_formats = formats
        _set_detail(:formats, formats[0,1])

        begin
          yield
        ensure
          _set_detail(:formats, old_formats)
        end
      end
    end
  end
end
