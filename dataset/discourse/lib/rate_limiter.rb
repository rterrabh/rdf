require_dependency 'rate_limiter/limit_exceeded'
require_dependency 'rate_limiter/on_create_record'

class RateLimiter

  attr_reader :max, :secs, :user, :key

  def self.key_prefix
    "l-rate-limit:"
  end

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  def self.disabled?
    @disabled || Rails.env.test?
  end

  def self.clear_all!
    $redis.delete_prefixed(RateLimiter.key_prefix)
  end

  def initialize(user, key, max, secs)
    @user = user
    @key = "#{RateLimiter.key_prefix}:#{@user && @user.id}:#{key}"
    @max = max
    @secs = secs
  end

  def clear!
    $redis.del(@key)
  end

  def can_perform?
    rate_unlimited? || is_under_limit?
  end

  def performed!
    return if rate_unlimited?

    if is_under_limit?
      $redis.lpush(@key, Time.now.to_i)
      $redis.ltrim(@key, 0, @max - 1)

      $redis.expire(@key, @secs * 2)
    else
      raise LimitExceeded.new(seconds_to_wait)
    end
  end

  def rollback!
    return if RateLimiter.disabled?
    $redis.lpop(@key)
  end

  private

  def seconds_to_wait
    @secs - age_of_oldest
  end

  def age_of_oldest
    Time.now.to_i - $redis.lrange(@key, -1, -1).first.to_i
  end

  def is_under_limit?
    ($redis.llen(@key) < @max) ||
    (age_of_oldest > @secs)
  end

  def rate_unlimited?
    !!(RateLimiter.disabled? || (@user && @user.staff?))
  end
end
