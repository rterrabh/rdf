require 'thread_safe'
require 'action_view/dependency_tracker'
require 'monitor'

module ActionView
  class Digestor
    cattr_reader(:cache)
    @@cache          = ThreadSafe::Cache.new
    @@digest_monitor = Monitor.new

    class << self
      def digest(options)
        options.assert_valid_keys(:name, :finder, :dependencies, :partial)

        cache_key = ([ options[:name], options[:finder].details_key.hash ].compact + Array.wrap(options[:dependencies])).join('.')

        @@cache[cache_key] || @@digest_monitor.synchronize do
          @@cache.fetch(cache_key) do # re-check under lock
            compute_and_store_digest(cache_key, options)
          end
        end
      end

      private
        def compute_and_store_digest(cache_key, options) # called under @@digest_monitor lock
          klass = if options[:partial] || options[:name].include?("/_")
            pre_stored = @@cache.put_if_absent(cache_key, false).nil? # put_if_absent returns nil on insertion
            PartialDigestor
          else
            Digestor
          end

          digest = klass.new(options).digest
          @@cache[cache_key] = stored_digest = digest if ActionView::Resolver.caching?
          digest
        ensure
          @@cache.delete_pair(cache_key, false) if pre_stored && !stored_digest
        end
    end

    attr_reader :name, :finder, :options

    def initialize(options)
      @name, @finder = options.values_at(:name, :finder)
      @options = options.except(:name, :finder)
    end

    def digest
      Digest::MD5.hexdigest("#{source}-#{dependency_digest}").tap do |digest|
        logger.try :debug, "  Cache digest for #{template.inspect}: #{digest}"
      end
    rescue ActionView::MissingTemplate
      logger.try :error, "  Couldn't find template for digesting: #{name}"
      ''
    end

    def dependencies
      DependencyTracker.find_dependencies(name, template)
    rescue ActionView::MissingTemplate
      logger.try :error, "  '#{name}' file doesn't exist, so no dependencies"
      []
    end

    def nested_dependencies
      dependencies.collect do |dependency|
        dependencies = PartialDigestor.new(name: dependency, finder: finder).nested_dependencies
        dependencies.any? ? { dependency => dependencies } : dependency
      end
    end

    private
      def logger
        ActionView::Base.logger
      end

      def logical_name
        name.gsub(%r|/_|, "/")
      end

      def partial?
        false
      end

      def template
        @template ||= finder.disable_cache { finder.find(logical_name, [], partial?) }
      end

      def source
        template.source
      end

      def dependency_digest
        template_digests = dependencies.collect do |template_name|
          Digestor.digest(name: template_name, finder: finder, partial: true)
        end

        (template_digests + injected_dependencies).join("-")
      end

      def injected_dependencies
        Array.wrap(options[:dependencies])
      end
  end

  class PartialDigestor < Digestor # :nodoc:
    def partial?
      true
    end
  end
end
