require 'fileutils'
require 'uri'
require 'set'

module ActionController
  module Caching
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Fragments
    end

    module ConfigMethods
      def cache_store
        config.cache_store
      end

      def cache_store=(store)
        config.cache_store = ActiveSupport::Cache.lookup_store(store)
      end

      private
        def cache_configured?
          perform_caching && cache_store
        end
    end

    include RackDelegation
    include AbstractController::Callbacks

    include ConfigMethods
    include Fragments

    included do
      extend ConfigMethods

      config_accessor :default_static_extension
      self.default_static_extension ||= '.html'

      config_accessor :perform_caching
      self.perform_caching = true if perform_caching.nil?

      class_attribute :_view_cache_dependencies
      self._view_cache_dependencies = []
      helper_method :view_cache_dependencies if respond_to?(:helper_method)
    end

    module ClassMethods
      def view_cache_dependency(&dependency)
        self._view_cache_dependencies += [dependency]
      end
    end

    def view_cache_dependencies
      #nodyna <instance_exec-1308> <IEX COMPLEX (block without parameters)>
      self.class._view_cache_dependencies.map { |dep| instance_exec(&dep) }.compact
    end

    protected
      def cache(key, options = {}, &block)
        if cache_configured?
          cache_store.fetch(ActiveSupport::Cache.expand_cache_key(key, :controller), options, &block)
        else
          yield
        end
      end
  end
end
