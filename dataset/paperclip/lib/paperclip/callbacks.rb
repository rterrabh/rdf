module Paperclip
  module Callbacks
    def self.included(base)
      base.extend(Defining)
      #nodyna <send-694> <SD TRIVIAL (public methods)>
      base.send(:include, Running)
    end

    module Defining
      def define_paperclip_callbacks(*callbacks)
        define_callbacks(*[callbacks, {:terminator => callback_terminator}].flatten)
        callbacks.each do |callback|
          #nodyna <eval-695> <EV COMPLEX (method definition)>
          eval <<-end_callbacks
            def before_#{callback}(*args, &blk)
              set_callback(:#{callback}, :before, *args, &blk)
            end
            def after_#{callback}(*args, &blk)
              set_callback(:#{callback}, :after, *args, &blk)
            end
          end_callbacks
        end
      end

      private

      def callback_terminator
        if ::ActiveSupport::VERSION::STRING >= '4.1'
          lambda { |target, result| result == false }
        else
          'result == false'
        end
      end
    end

    module Running
      def run_paperclip_callbacks(callback, &block)
        run_callbacks(callback, &block)
      end
    end
  end
end
