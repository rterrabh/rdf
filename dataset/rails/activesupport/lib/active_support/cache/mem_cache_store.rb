begin
  require 'dalli'
rescue LoadError => e
  $stderr.puts "You don't have dalli installed in your application. Please add it to your Gemfile and run bundle install"
  raise e
end

require 'digest/md5'
require 'active_support/core_ext/marshal'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  module Cache
    class MemCacheStore < Store
      ESCAPE_KEY_CHARS = /[\x00-\x20%\x7F-\xFF]/n

      def self.build_mem_cache(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        addresses = ["localhost:11211"] if addresses.empty?
        Dalli::Client.new(addresses, options)
      end

      def initialize(*addresses)
        addresses = addresses.flatten
        options = addresses.extract_options!
        super(options)

        unless [String, Dalli::Client, NilClass].include?(addresses.first.class)
          raise ArgumentError, "First argument must be an empty array, an array of hosts or a Dalli::Client instance."
        end
        if addresses.first.is_a?(Dalli::Client)
          @data = addresses.first
        else
          mem_cache_options = options.dup
          UNIVERSAL_OPTIONS.each{|name| mem_cache_options.delete(name)}
          @data = self.class.build_mem_cache(*(addresses + [mem_cache_options]))
        end

        extend Strategy::LocalCache
        extend LocalCacheWithRaw
      end

      def read_multi(*names)
        options = names.extract_options!
        options = merged_options(options)
        keys_to_names = Hash[names.map{|name| [escape_key(namespaced_key(name, options)), name]}]
        raw_values = @data.get_multi(keys_to_names.keys, :raw => true)
        values = {}
        raw_values.each do |key, value|
          entry = deserialize_entry(value)
          values[keys_to_names[key]] = entry.value unless entry.expired?
        end
        values
      end

      def increment(name, amount = 1, options = nil) # :nodoc:
        options = merged_options(options)
        instrument(:increment, name, :amount => amount) do
          @data.incr(escape_key(namespaced_key(name, options)), amount)
        end
      rescue Dalli::DalliError => e
        logger.error("DalliError (#{e}): #{e.message}") if logger
        nil
      end

      def decrement(name, amount = 1, options = nil) # :nodoc:
        options = merged_options(options)
        instrument(:decrement, name, :amount => amount) do
          @data.decr(escape_key(namespaced_key(name, options)), amount)
        end
      rescue Dalli::DalliError => e
        logger.error("DalliError (#{e}): #{e.message}") if logger
        nil
      end

      def clear(options = nil)
        @data.flush_all
      rescue Dalli::DalliError => e
        logger.error("DalliError (#{e}): #{e.message}") if logger
        nil
      end

      def stats
        @data.stats
      end

      protected
        def read_entry(key, options) # :nodoc:
          deserialize_entry(@data.get(escape_key(key), options))
        rescue Dalli::DalliError => e
          logger.error("DalliError (#{e}): #{e.message}") if logger
          nil
        end

        def write_entry(key, entry, options) # :nodoc:
          method = options && options[:unless_exist] ? :add : :set
          value = options[:raw] ? entry.value.to_s : entry
          expires_in = options[:expires_in].to_i
          if expires_in > 0 && !options[:raw]
            expires_in += 5.minutes
          end
          #nodyna <send-1002> <SD MODERATE (change-prone variables)>
          @data.send(method, escape_key(key), value, expires_in, options)
        rescue Dalli::DalliError => e
          logger.error("DalliError (#{e}): #{e.message}") if logger
          false
        end

        def delete_entry(key, options) # :nodoc:
          @data.delete(escape_key(key))
        rescue Dalli::DalliError => e
          logger.error("DalliError (#{e}): #{e.message}") if logger
          false
        end

      private

        def escape_key(key)
          key = key.to_s.dup
          key = key.force_encoding(Encoding::ASCII_8BIT)
          key = key.gsub(ESCAPE_KEY_CHARS){ |match| "%#{match.getbyte(0).to_s(16).upcase}" }
          key = "#{key[0, 213]}:md5:#{Digest::MD5.hexdigest(key)}" if key.size > 250
          key
        end

        def deserialize_entry(raw_value)
          if raw_value
            entry = Marshal.load(raw_value) rescue raw_value
            entry.is_a?(Entry) ? entry : Entry.new(entry)
          else
            nil
          end
        end

      module LocalCacheWithRaw # :nodoc:
        protected
          def read_entry(key, options)
            entry = super
            if options[:raw] && local_cache && entry
               entry = deserialize_entry(entry.value)
            end
            entry
          end

          def write_entry(key, entry, options) # :nodoc:
            retval = super
            if options[:raw] && local_cache && retval
              raw_entry = Entry.new(entry.value.to_s)
              raw_entry.expires_at = entry.expires_at
              local_cache.write_entry(key, raw_entry, options)
            end
            retval
          end
      end
    end
  end
end
