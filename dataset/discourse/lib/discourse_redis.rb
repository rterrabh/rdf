require_dependency 'cache'
class DiscourseRedis

  def self.raw_connection(config = nil)
    config ||= self.config
    Redis.new(config)
  end

  def self.config
    GlobalSetting.redis_config
  end

  def initialize(config=nil)
    @config = config || DiscourseRedis.config
    @redis = DiscourseRedis.raw_connection(@config)
  end

  def without_namespace
    @redis
  end

  def self.ignore_readonly
    yield
  rescue Redis::CommandError => ex
    if ex.message =~ /READONLY/
      unless Discourse.recently_readonly?
        STDERR.puts "WARN: Redis is in a readonly state. Performed a noop"
      end
      Discourse.received_readonly!
    else
      raise ex
    end
  end

  def method_missing(meth, *args, &block)
    if @redis.respond_to?(meth)
      #nodyna <send-334> <SD COMPLEX (change-prone variables)>
      DiscourseRedis.ignore_readonly { @redis.send(meth, *args, &block) }
    else
      super
    end
  end

  [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby, :exists, :expire, :expireat, :get, :getbit, :getrange, :getset,
   :hdel, :hexists, :hget, :hgetall, :hincrby, :hincrbyfloat, :hkeys, :hlen, :hmget, :hmset, :hset, :hsetnx, :hvals, :incr,
   :incrby, :incrbyfloat, :lindex, :linsert, :llen, :lpop, :lpush, :lpushx, :lrange, :lrem, :lset, :ltrim,
   :mapped_hmset, :mapped_hmget, :mapped_mget, :mapped_mset, :mapped_msetnx, :mget, :move, :mset,
   :msetnx, :persist, :pexpire, :pexpireat, :psetex, :pttl, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx, :sadd, :scard,
   :sdiff, :set, :setbit, :setex, :setnx, :setrange, :sinter, :sismember, :smembers, :sort, :spop, :srandmember, :srem, :strlen,
   :sunion, :ttl, :type, :watch, :zadd, :zcard, :zcount, :zincrby, :zrange, :zrangebyscore, :zrank, :zrem, :zremrangebyrank,
   :zremrangebyscore, :zrevrange, :zrevrangebyscore, :zrevrank, :zrangebyscore].each do |m|
    #nodyna <define_method-335> <DM MODERATE (array)>
    define_method m do |*args|
      args[0] = "#{namespace}:#{args[0]}"
      #nodyna <send-336> <SD MODERATE (change-prone variables)>
      DiscourseRedis.ignore_readonly { @redis.send(m, *args) }
    end
  end

  def del(k)
    DiscourseRedis.ignore_readonly do
      k = "#{namespace}:#{k}"
      @redis.del k
    end
  end

  def keys(pattern=nil)
    DiscourseRedis.ignore_readonly do
      len = namespace.length + 1
      @redis.keys("#{namespace}:#{pattern || '*'}").map{
        |k| k[len..-1]
      }
    end
  end

  def delete_prefixed(prefix)
    DiscourseRedis.ignore_readonly do
      keys("#{prefix}*").each { |k| $redis.del(k) }
    end
  end

  def flushdb
    DiscourseRedis.ignore_readonly do
      keys.each{|k| del(k)}
    end
  end

  def reconnect
    @redis.client.reconnect
  end

  def namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.namespace
    Rails.logger.warn("DiscourseRedis.namespace is going to be deprecated, do not use it!")
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.new_redis_store
    Cache.new
  end

end
