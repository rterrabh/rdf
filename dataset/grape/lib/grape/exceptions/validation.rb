require 'grape/exceptions/base'

module Grape
  module Exceptions
    class Validation < Grape::Exceptions::Base
      attr_accessor :params

      def initialize(args = {})
        fail 'Params are missing:' unless args.key? :params
        @params = args[:params]
        args[:message] = translate_message(args[:message_key]) if args.key? :message_key
        super
      end

      def as_json(*_args)
        to_s
      end

      def to_s
        message
      end
    end
  end
end
