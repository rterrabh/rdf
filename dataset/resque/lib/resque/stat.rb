module Resque
  module Stat
    extend self
    
    def redis
      Resque.redis
    end

    def get(stat)
      redis.get("stat:#{stat}").to_i
    end

    def [](stat)
      get(stat)
    end

    def incr(stat, by = 1)
      redis.incrby("stat:#{stat}", by)
    end

    def <<(stat)
      incr stat
    end

    def decr(stat, by = 1)
      redis.decrby("stat:#{stat}", by)
    end

    def >>(stat)
      decr stat
    end

    def clear(stat)
      redis.del("stat:#{stat}")
    end
  end
end
