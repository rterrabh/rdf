module Jobs
  module Stats
    def set_cache(klass, stats)
      $redis.setex klass.stats_cache_key, (klass.recalculate_stats_interval + 5).minutes, stats.to_json
    end
  end
end
