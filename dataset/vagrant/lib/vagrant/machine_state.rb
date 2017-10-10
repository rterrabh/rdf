module Vagrant
  class MachineState
    NOT_CREATED_ID = :not_created

    attr_reader :id

    attr_reader :short_description

    attr_reader :long_description

    def initialize(id, short, long)
      @id                = id
      @short_description = short
      @long_description  = long
    end
  end
end
