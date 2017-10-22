
module CarrierWave
  module Uploader
    module Processing
      extend ActiveSupport::Concern

      include CarrierWave::Uploader::Callbacks

      included do
        class_attribute :processors, :instance_writer => false
        self.processors = []

        after :cache, :process!
      end

      module ClassMethods

        def process(*args)
          new_processors = args.inject({}) do |hash, arg|
            arg = { arg => [] } unless arg.is_a?(Hash)
            hash.merge!(arg)
          end

          condition = new_processors.delete(:if)
          new_processors.each do |processor, processor_args|
            self.processors += [[processor, processor_args, condition]]
          end
        end

      end # ClassMethods

      def process!(new_file=nil)
        return unless enable_processing

        self.class.processors.each do |method, args, condition|
          if(condition)
            if condition.respond_to?(:call)
              next unless condition.call(self, :args => args, :method => method, :file => new_file)
            else
              #nodyna <send-2676> <SD COMPLEX (change-prone variables)>
              next unless self.send(condition, new_file)
            end
          end
          #nodyna <send-2677> <SD COMPLEX (change-prone variables)>
          self.send(method, *args)
        end
      end

    end # Processing
  end # Uploader
end # CarrierWave
