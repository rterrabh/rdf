require 'thread'

module Singleton
  def clone
    raise TypeError, "can't clone instance of singleton #{self.class}"
  end

  def dup
    raise TypeError, "can't dup instance of singleton #{self.class}"
  end

  def _dump(depth = -1)
    ''
  end

  module SingletonClassMethods # :nodoc:

    def clone # :nodoc:
      Singleton.__init__(super)
    end

    def _load(str)
      instance
    end

    private

    def inherited(sub_klass)
      super
      Singleton.__init__(sub_klass)
    end
  end

  class << Singleton # :nodoc:
    def __init__(klass) # :nodoc:
      #nodyna <instance_eval-2354> <IEV COMPLEX (private access)>
      klass.instance_eval {
        @singleton__instance__ = nil
        @singleton__mutex__ = Mutex.new
      }
      def klass.instance # :nodoc:
        return @singleton__instance__ if @singleton__instance__
        @singleton__mutex__.synchronize {
          return @singleton__instance__ if @singleton__instance__
          @singleton__instance__ = new()
        }
        @singleton__instance__
      end
      klass
    end

    private

    undef_method :extend_object

    def append_features(mod)
      unless mod.instance_of?(Class)
        raise TypeError, "Inclusion of the OO-Singleton module in module #{mod}"
      end
      super
    end

    def included(klass)
      super
      klass.private_class_method :new, :allocate
      klass.extend SingletonClassMethods
      Singleton.__init__(klass)
    end
  end

end
