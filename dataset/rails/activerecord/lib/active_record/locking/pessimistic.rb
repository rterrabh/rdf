module ActiveRecord
  module Locking
    module Pessimistic
      def lock!(lock = true)
        reload(:lock => lock) if persisted?
        self
      end

      def with_lock(lock = true)
        transaction do
          lock!(lock)
          yield
        end
      end
    end
  end
end
