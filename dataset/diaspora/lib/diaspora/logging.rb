module Diaspora
  module Logging
    private

    def logger
      @logger ||= ::Logging::Logger[self]
    end
  end
end
