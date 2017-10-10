module ActiveSupport
  class ProxyObject < ::BasicObject
    undef_method :==
    undef_method :equal?

    def raise(*args)
      #nodyna <send-1003> <SD COMPLEX (private methods)>
      ::Object.send(:raise, *args)
    end
  end
end
