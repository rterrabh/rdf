require 'observer'

module DRb
  module DRbObservable
    include Observable

    def notify_observers(*arg)
      if defined? @observer_state and @observer_state
        if defined? @observer_peers
          @observer_peers.each do |observer, method|
            begin
              #nodyna <send-2046> <SD COMPLEX (change-prone variables)>
              observer.send(method, *arg)
            rescue
              delete_observer(observer)
            end
          end
        end
        @observer_state = false
      end
    end
  end
end
