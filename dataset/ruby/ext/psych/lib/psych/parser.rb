module Psych

  class Parser
    class Mark < Struct.new(:index, :line, :column)
    end

    attr_accessor :handler

    attr_writer :external_encoding


    def initialize handler = Handler.new
      @handler = handler
      @external_encoding = ANY
    end
  end
end
