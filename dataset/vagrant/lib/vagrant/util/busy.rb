module Vagrant
  module Util
    class Busy
      @@registered = []
      @@mutex = Mutex.new

      class << self
        def busy(sig_callback)
          register(sig_callback)
          return yield
        ensure
          unregister(sig_callback)
        end

        def register(sig_callback)
          @@mutex.synchronize do
            registered << sig_callback
            registered.uniq!

            Signal.trap("INT") { fire_callbacks } if registered.length == 1
          end
        end

        def unregister(sig_callback)
          @@mutex.synchronize do
            registered.delete(sig_callback)

            Signal.trap("INT", "DEFAULT") if registered.empty?
          end
        end

        def fire_callbacks
          registered.reverse.each { |r| r.call }
        end

        def registered; @@registered; end
      end
    end
  end
end
