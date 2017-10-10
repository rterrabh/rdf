module Fiddle
  class Function
    attr_reader :abi

    attr_reader :ptr

    attr_reader :name

    def to_i
      ptr.to_i
    end
  end
end
