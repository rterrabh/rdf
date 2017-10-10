require 'benchmark'
require 'zlib'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/benchmark'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/numeric/bytes'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/string/inflections'
require 'active_support/deprecation'

module ActiveSupport
  module Cache
    autoload :FileStore,     'active_support/cache/file_store'
    autoload :MemoryStore,   'active_support/cache/memory_store'
    autoload :MemCacheStore, 'active_support/cache/mem_cache_store'
    autoload :NullStore,     'active_support/cache/null_store'

    UNIVERSAL_OPTIONS = [:namespace, :compress, :compress_threshold, :expires_in, :race_condition_ttl]

    module Strategy
      autoload :LocalCache, 'active_support/cache/strategy/local_cache'
    end

    class << self
      def lookup_store(*store_option)
        store, *parameters = *Array.wrap(store_option).flatten

        case store
        when Symbol
          retrieve_store_class(store).new(*parameters)
        when nil
          ActiveSupport::Cache::MemoryStore.new
        else
          store
        end
      end

      def expand_cache_key(key, namespace = nil)
        expanded_cache_key = namespace ? "#{namespace}/" : ""

        if prefix = ENV["RAILS_CACHE_ID"] || ENV["RAILS_APP_VERSION"]
          expanded_cache_key << "#{prefix}/"
        end

        expanded_cache_key << retrieve_cache_key(key)
        expanded_cache_key
      end

      private
        def retrieve_cache_key(key)
          case
          when key.respond_to?(:cache_key) then key.cache_key
          when key.is_a?(Array)            then key.map { |element| retrieve_cache_key(element) }.to_param
          when key.respond_to?(:to_a)      then retrieve_cache_key(key.to_a)
          else                                  key.to_param
          end.to_s
        end

        def retrieve_store_class(store)
          require "active_support/cache/#{store}"
        rescue LoadError => e
          raise "Could not find cache store adapter for #{store} (#{e})"
        else
          #nodyna <const_get-1001> <CG COMPLEX (change-prone variable)>
          ActiveSupport::Cache.const_get(store.to_s.camelize)
        end
    end

    class Store
      cattr_accessor :logger, :instance_writer => true

      attr_reader :silence, :options
      alias :silence? :silence

      def initialize(options = nil)
        @options = options ? options.dup : {}
      end

      def silence!
        @silence = true
        self
      end

      def mute
        previous_silence, @silence = defined?(@silence) && @silence, true
        yield
      ensure
        @silence = previous_silence
      end

      def self.instrument=(boolean)
        ActiveSupport::Deprecation.warn "ActiveSupport::Cache.instrument= is deprecated and will be removed in Rails 5. Instrumentation is now always on so you can safely stop using it."
        true
      end

      def self.instrument
        ActiveSupport::Deprecation.warn "ActiveSupport::Cache.instrument is deprecated and will be removed in Rails 5. Instrumentation is now always on so you can safely stop using it."
        true
      end

      def fetch(name, options = nil)
        if block_given?
          options = merged_options(options)
          key = namespaced_key(name, options)

          cached_entry = find_cached_entry(key, name, options) unless options[:force]
          entry = handle_expired_entry(cached_entry, key, options)

          if entry
            get_entry_value(entry, name, options)
          else
            save_block_result_to_cache(name, options) { |_name| yield _name }
          end
        else
          read(name, options)
        end
      end

      def read(name, options = nil)
        options = merged_options(options)
        key = namespaced_key(name, options)
        instrument(:read, name, options) do |payload|
          entry = read_entry(key, options)
          if entry
            if entry.expired?
              delete_entry(key, options)
              payload[:hit] = false if payload
              nil
            else
              payload[:hit] = true if payload
              entry.value
            end
          else
            payload[:hit] = false if payload
            nil
          end
        end
      end

      def read_multi(*names)
        options = names.extract_options!
        options = merged_options(options)
        results = {}
        names.each do |name|
          key = namespaced_key(name, options)
          entry = read_entry(key, options)
          if entry
            if entry.expired?
              delete_entry(key, options)
            else
              results[name] = entry.value
            end
          end
        end
        results
      end

      def fetch_multi(*names)
        options = names.extract_options!
        options = merged_options(options)
        results = read_multi(*names, options)

        names.each_with_object({}) do |name, memo|
          memo[name] = results.fetch(name) do
            value = yield name
            write(name, value, options)
            value
          end
        end
      end

      def write(name, value, options = nil)
        options = merged_options(options)

        instrument(:write, name, options) do
          entry = Entry.new(value, options)
          write_entry(namespaced_key(name, options), entry, options)
        end
      end

      def delete(name, options = nil)
        options = merged_options(options)

        instrument(:delete, name) do
          delete_entry(namespaced_key(name, options), options)
        end
      end

      def exist?(name, options = nil)
        options = merged_options(options)

        instrument(:exist?, name) do
          entry = read_entry(namespaced_key(name, options), options)
          (entry && !entry.expired?) || false
        end
      end

      def delete_matched(matcher, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support delete_matched")
      end

      def increment(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support increment")
      end

      def decrement(name, amount = 1, options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support decrement")
      end

      def cleanup(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support cleanup")
      end

      def clear(options = nil)
        raise NotImplementedError.new("#{self.class.name} does not support clear")
      end

      protected
        def key_matcher(pattern, options)
          prefix = options[:namespace].is_a?(Proc) ? options[:namespace].call : options[:namespace]
          if prefix
            source = pattern.source
            if source.start_with?('^')
              source = source[1, source.length]
            else
              source = ".*#{source[0, source.length]}"
            end
            Regexp.new("^#{Regexp.escape(prefix)}:#{source}", pattern.options)
          else
            pattern
          end
        end

        def read_entry(key, options) # :nodoc:
          raise NotImplementedError.new
        end

        def write_entry(key, entry, options) # :nodoc:
          raise NotImplementedError.new
        end

        def delete_entry(key, options) # :nodoc:
          raise NotImplementedError.new
        end

      private
        def merged_options(call_options) # :nodoc:
          if call_options
            options.merge(call_options)
          else
            options.dup
          end
        end

        def expanded_key(key) # :nodoc:
          return key.cache_key.to_s if key.respond_to?(:cache_key)

          case key
          when Array
            if key.size > 1
              key = key.collect{|element| expanded_key(element)}
            else
              key = key.first
            end
          when Hash
            key = key.sort_by { |k,_| k.to_s }.collect{|k,v| "#{k}=#{v}"}
          end

          key.to_param
        end

        def namespaced_key(key, options)
          key = expanded_key(key)
          namespace = options[:namespace] if options
          prefix = namespace.is_a?(Proc) ? namespace.call : namespace
          key = "#{prefix}:#{key}" if prefix
          key
        end

        def instrument(operation, key, options = nil)
          log(operation, key, options)

          payload = { :key => key }
          payload.merge!(options) if options.is_a?(Hash)
          ActiveSupport::Notifications.instrument("cache_#{operation}.active_support", payload){ yield(payload) }
        end

        def log(operation, key, options = nil)
          return unless logger && logger.debug? && !silence?
          logger.debug("Cache #{operation}: #{key}#{options.blank? ? "" : " (#{options.inspect})"}")
        end

        def find_cached_entry(key, name, options)
          instrument(:read, name, options) do |payload|
            payload[:super_operation] = :fetch if payload
            read_entry(key, options)
          end
        end

        def handle_expired_entry(entry, key, options)
          if entry && entry.expired?
            race_ttl = options[:race_condition_ttl].to_i
            if (race_ttl > 0) && (Time.now.to_f - entry.expires_at <= race_ttl)
              entry.expires_at = Time.now + race_ttl
              write_entry(key, entry, :expires_in => race_ttl * 2)
            else
              delete_entry(key, options)
            end
            entry = nil
          end
          entry
        end

        def get_entry_value(entry, name, options)
          instrument(:fetch_hit, name, options) { |payload| }
          entry.value
        end

        def save_block_result_to_cache(name, options)
          result = instrument(:generate, name, options) do |payload|
            yield(name)
          end

          write(name, result, options)
          result
        end
    end

    class Entry # :nodoc:
      DEFAULT_COMPRESS_LIMIT = 16.kilobytes

      def initialize(value, options = {})
        if should_compress?(value, options)
          @value = compress(value)
          @compressed = true
        else
          @value = value
        end

        @created_at = Time.now.to_f
        @expires_in = options[:expires_in]
        @expires_in = @expires_in.to_f if @expires_in
      end

      def value
        convert_version_4beta1_entry! if defined?(@v)
        compressed? ? uncompress(@value) : @value
      end

      def expired?
        convert_version_4beta1_entry! if defined?(@v)
        @expires_in && @created_at + @expires_in <= Time.now.to_f
      end

      def expires_at
        @expires_in ? @created_at + @expires_in : nil
      end

      def expires_at=(value)
        if value
          @expires_in = value.to_f - @created_at
        else
          @expires_in = nil
        end
      end

      def size
        if defined?(@s)
          @s
        else
          case value
          when NilClass
            0
          when String
            @value.bytesize
          else
            @s = Marshal.dump(@value).bytesize
          end
        end
      end

      def dup_value!
        convert_version_4beta1_entry! if defined?(@v)

        if @value && !compressed? && !(@value.is_a?(Numeric) || @value == true || @value == false)
          if @value.is_a?(String)
            @value = @value.dup
          else
            @value = Marshal.load(Marshal.dump(@value))
          end
        end
      end

      private
        def should_compress?(value, options)
          if value && options[:compress]
            compress_threshold = options[:compress_threshold] || DEFAULT_COMPRESS_LIMIT
            serialized_value_size = (value.is_a?(String) ? value : Marshal.dump(value)).bytesize

            return true if serialized_value_size >= compress_threshold
          end

          false
        end

        def compressed?
          defined?(@compressed) ? @compressed : false
        end

        def compress(value)
          Zlib::Deflate.deflate(Marshal.dump(value))
        end

        def uncompress(value)
          Marshal.load(Zlib::Inflate.inflate(value))
        end

        def convert_version_4beta1_entry!
          if defined?(@v)
            @value = @v
            remove_instance_variable(:@v)
          end

          if defined?(@c)
            @compressed = @c
            remove_instance_variable(:@c)
          end

          if defined?(@x) && @x
            @created_at ||= Time.now.to_f
            @expires_in = @x - @created_at
            remove_instance_variable(:@x)
          end
        end
    end
  end
end
