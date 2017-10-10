
class Cache < ActiveSupport::Cache::Store

  MAX_CACHE_AGE = 1.day unless defined? MAX_CACHE_AGE

  def initialize(opts = {})
    @namespace = opts[:namespace] || "_CACHE_"
    super(opts)
  end

  def redis
    $redis
  end

  def reconnect
    redis.reconnect
  end

  def clear
    redis.keys("#{@namespace}:*").each do |k|
      redis.del(k)
    end
  end

  def namespaced_key(key, opts=nil)
    "#{@namespace}:" << key
  end

  protected

  def read_entry(key, options)
    if data = redis.get(key)
      data = Marshal.load(data)
      ActiveSupport::Cache::Entry.new data
    end
  rescue
  end

  def write_entry(key, entry, options)
    dumped = Marshal.dump(entry.value)
    expiry = options[:expires_in] || MAX_CACHE_AGE
    redis.setex(key, expiry, dumped)
    true
  end

  def delete_entry(key, options)
    redis.del key
  end

end
