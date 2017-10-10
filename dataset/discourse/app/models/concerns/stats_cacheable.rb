module StatsCacheable
  extend ActiveSupport::Concern

  module ClassMethods
    def stats_cache_key
      raise 'Stats cache key has not been set.'
    end

    def fetch_stats
      raise 'Not implemented.'
    end

    def recalculate_stats_interval
      30 # minutes
    end

    def fetch_cached_stats
      stats = $redis.get(stats_cache_key)
      stats ? JSON.parse(stats) : nil
    end
  end
end
