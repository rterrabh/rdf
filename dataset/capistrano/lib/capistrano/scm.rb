module Capistrano

  class SCM
    attr_reader :context

    def initialize(context, strategy)
      @context = context
      singleton = class << self; self; end
      #nodyna <send-2623> <SD TRIVIAL (public methods)>
      singleton.send(:include, strategy)
    end

    def test!(*args)
      context.test *args
    end

    def repo_url
      context.repo_url
    end

    def repo_path
      context.repo_path
    end

    def release_path
      context.release_path
    end

    def fetch(*args)
      context.fetch(*args)
    end

    def test
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #test method"
      )
    end

    def check
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #check method"
      )
    end

    def clone
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #clone method"
      )
    end

    def update
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #update method"
      )
    end

    def release
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #release method"
      )
    end

    def fetch_revision
      raise NotImplementedError.new(
        "Your SCM strategy module should provide a #fetch_revision method"
      )
    end
  end
end
