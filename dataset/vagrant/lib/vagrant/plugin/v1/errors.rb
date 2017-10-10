
module Vagrant
  module Plugin
    module V1
      class Error < StandardError; end

      class InvalidCommandName < Error; end
    end
  end
end
