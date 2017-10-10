module ActiveAdmin

  module Authorization
    READ    = :read
    CREATE  = :create
    UPDATE  = :update
    DESTROY = :destroy
  end

  Auth = Authorization


  class AuthorizationAdapter
    attr_reader :resource, :user


    def initialize(resource, user)
      @resource = resource
      @user = user
    end

    def authorized?(action, subject = nil)
      true
    end


    def scope_collection(collection, action = Auth::READ)
      collection
    end

    private

    def normalized(klass)
      NormalizedMatcher.new(klass)
    end

    class NormalizedMatcher

      def initialize(klass)
        @klass = klass
      end

      def ===(other)
        @klass == other || other.is_a?(@klass)
      end

    end

  end

end
