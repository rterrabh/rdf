module Autospec

  class BaseRunner

    def start(opts = {})
    end

    def running?
      true
    end

    def run(specs)
    end

    def reload
    end

    def abort
    end

    def failed_specs
      []
    end

    def stop
    end

  end

end
