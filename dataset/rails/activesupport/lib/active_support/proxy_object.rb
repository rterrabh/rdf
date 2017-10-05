module ActiveSupport
  # A class with no predefined methods that behaves similarly to Builder's
  # BlankSlate. Used for proxy classes.
  class ProxyObject < ::BasicObject
    undef_method :==
    undef_method :equal?

    # Let ActiveSupport::ProxyObject at least raise exceptions.
    def raise(*args)
      #nodyna <ID:send-237> <SD COMPLEX (private methods)>
      ::Object.send(:raise, *args)
    end
  end
end
