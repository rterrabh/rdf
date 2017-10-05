class BasePresenter
  attr_reader :current_user

  class << self
    def new(*args)
      return NilPresenter.new if args[0].nil?
      super *args
    end

    def as_collection(collection, method=:as_json, *args)
      #nodyna <ID:send-247> <SD MODERATE (array)>
      collection.map{|object| self.new(object, *args).send(method) }
    end
  end

  def initialize(presentable, curr_user=nil)
    @presentable = presentable
    @current_user = curr_user
  end

  def method_missing(method, *args)
    #nodyna <ID:send-248> <SD COMPLEX (change-prone variables)>
    @presentable.public_send(method, *args)
  end

  class NilPresenter
    def method_missing(method, *args)
      nil
    end
  end
end
