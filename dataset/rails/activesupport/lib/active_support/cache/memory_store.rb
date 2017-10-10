require 'monitor'

module ActiveSupport
  module Cache
    class MemoryStore < Store
      def initialize(options = nil)
        options ||= {}
        super(options)
        @data = {}
        @key_access = {}
        @max_size = options[:size] || 32.megabytes
        @max_prune_time = options[:max_prune_time] || 2
        @cache_size = 0
        @monitor = Monitor.new
        @pruning = false
      end

      def clear(options = nil)
        synchronize do
          @data.clear
          @key_access.clear
          @cache_size = 0
        end
      end

      def cleanup(options = nil)
        options = merged_options(options)
        instrument(:cleanup, :size => @data.size) do
          keys = synchronize{ @data.keys }
          keys.each do |key|
            entry = @data[key]
            delete_entry(key, options) if entry && entry.expired?
          end
        end
      end

      def prune(target_size, max_time = nil)
        return if pruning?
        @pruning = true
        begin
          start_time = Time.now
          cleanup
          instrument(:prune, target_size, :from => @cache_size) do
            keys = synchronize{ @key_access.keys.sort{|a,b| @key_access[a].to_f <=> @key_access[b].to_f} }
            keys.each do |key|
              delete_entry(key, options)
              return if @cache_size <= target_size || (max_time && Time.now - start_time > max_time)
            end
          end
        ensure
          @pruning = false
        end
      end

      def pruning?
        @pruning
      end

      def increment(name, amount = 1, options = nil)
        synchronize do
          options = merged_options(options)
          if num = read(name, options)
            num = num.to_i + amount
            write(name, num, options)
            num
          else
            nil
          end
        end
      end

      def decrement(name, amount = 1, options = nil)
        synchronize do
          options = merged_options(options)
          if num = read(name, options)
            num = num.to_i - amount
            write(name, num, options)
            num
          else
            nil
          end
        end
      end

      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        instrument(:delete_matched, matcher.inspect) do
          matcher = key_matcher(matcher, options)
          keys = synchronize { @data.keys }
          keys.each do |key|
            delete_entry(key, options) if key.match(matcher)
          end
        end
      end

      def inspect # :nodoc:
        "<##{self.class.name} entries=#{@data.size}, size=#{@cache_size}, options=#{@options.inspect}>"
      end

      def synchronize(&block) # :nodoc:
        @monitor.synchronize(&block)
      end

      protected

        PER_ENTRY_OVERHEAD = 240

        def cached_size(key, entry)
          key.to_s.bytesize + entry.size + PER_ENTRY_OVERHEAD
        end

        def read_entry(key, options) # :nodoc:
          entry = @data[key]
          synchronize do
            if entry
              @key_access[key] = Time.now.to_f
            else
              @key_access.delete(key)
            end
          end
          entry
        end

        def write_entry(key, entry, options) # :nodoc:
          entry.dup_value!
          synchronize do
            old_entry = @data[key]
            return false if @data.key?(key) && options[:unless_exist]
            if old_entry
              @cache_size -= (old_entry.size - entry.size)
            else
              @cache_size += cached_size(key, entry)
            end
            @key_access[key] = Time.now.to_f
            @data[key] = entry
            prune(@max_size * 0.75, @max_prune_time) if @cache_size > @max_size
            true
          end
        end

        def delete_entry(key, options) # :nodoc:
          synchronize do
            @key_access.delete(key)
            entry = @data.delete(key)
            @cache_size -= cached_size(key, entry) if entry
            !!entry
          end
        end
    end
  end
end
