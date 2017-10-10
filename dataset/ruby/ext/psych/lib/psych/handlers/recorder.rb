require 'psych/handler'

module Psych
  module Handlers

    class Recorder < Psych::Handler
      attr_reader :events

      def initialize
        @events = []
        super
      end

      EVENTS.each do |event|
        #nodyna <define_method-1482> <DM MODERATE (array)>
        define_method event do |*args|
          @events << [event, args]
        end
      end
    end
  end
end
