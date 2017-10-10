class RateLimiter

  module OnCreateRecord

    def default_rate_limiter
      return @rate_limiter if @rate_limiter.present?

      limit_key = "create_#{self.class.name.underscore}"
      max_setting = if user.new_user? and SiteSetting.has_setting?("rate_limit_new_user_#{limit_key}")
        #nodyna <send-337> <SD COMPLEX (change-prone variables)>
        SiteSetting.send("rate_limit_new_user_#{limit_key}")
      else
        #nodyna <send-338> <SD COMPLEX (change-prone variables)>
        SiteSetting.send("rate_limit_#{limit_key}")
      end
      @rate_limiter = RateLimiter.new(user, limit_key, 1, max_setting)
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def disable_rate_limits!
      @rate_limits_disabled = true
    end

    module ClassMethods
      def rate_limit(limiter_method=nil)

        limiter_method = limiter_method || :default_rate_limiter

        self.after_create do |*args|
          next if @rate_limits_disabled

          #nodyna <send-339> <SD MODERATE (change-prone variables)>
          if rate_limiter = send(limiter_method)
            rate_limiter.performed!
            @performed ||= {}
            @performed[limiter_method] = true
          end
        end

        self.after_destroy do
          next if @rate_limits_disabled
          #nodyna <send-340> <SD MODERATE (change-prone variables)>
          if rate_limiter = send(limiter_method)
            rate_limiter.rollback!
          end
        end

        self.after_rollback do
          next if @rate_limits_disabled
          #nodyna <send-341> <SD MODERATE (change-prone variables)>
          if rate_limiter = send(limiter_method)
            if @performed.present? && @performed[limiter_method]
              rate_limiter.rollback!
              @performed[limiter_method] = false
            end
          end
        end

      end
    end

  end

end
