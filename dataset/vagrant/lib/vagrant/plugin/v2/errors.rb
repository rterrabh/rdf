
module Vagrant
  module Plugin
    module V2
      class Error < StandardError; end

      class InvalidCommandName < Error; end
    end
  end
end
