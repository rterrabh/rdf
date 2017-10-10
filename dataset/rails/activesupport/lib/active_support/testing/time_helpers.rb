module ActiveSupport
  module Testing
    class SimpleStubs # :nodoc:
      Stub = Struct.new(:object, :method_name, :original_method)

      def initialize
        @stubs = {}
      end

      def stub_object(object, method_name, return_value)
        key = [object.object_id, method_name]

        if stub = @stubs[key]
          unstub_object(stub)
        end

        new_name = "__simple_stub__#{method_name}"

        @stubs[key] = Stub.new(object, method_name, new_name)

        #nodyna <send-1125> <SD COMPLEX (private methods)>
        object.singleton_class.send :alias_method, new_name, method_name
        object.define_singleton_method(method_name) { return_value }
      end

      def unstub_all!
        @stubs.each_value do |stub|
          unstub_object(stub)
        end
        @stubs = {}
      end

      private

        def unstub_object(stub)
          singleton_class = stub.object.singleton_class
          #nodyna <send-1126> <SD COMPLEX (private methods)>
          singleton_class.send :undef_method, stub.method_name
          #nodyna <send-1127> <SD COMPLEX (private methods)>
          singleton_class.send :alias_method, stub.method_name, stub.original_method
          #nodyna <send-1128> <SD COMPLEX (private methods)>
          singleton_class.send :undef_method, stub.original_method
        end
    end

    module TimeHelpers
      def travel(duration, &block)
        travel_to Time.now + duration, &block
      end

      def travel_to(date_or_time)
        if date_or_time.is_a?(Date) && !date_or_time.is_a?(DateTime)
          now = date_or_time.midnight.to_time
        else
          now = date_or_time.to_time.change(usec: 0)
        end

        simple_stubs.stub_object(Time, :now, now)
        simple_stubs.stub_object(Date, :today, now.to_date)

        if block_given?
          begin
            yield
          ensure
            travel_back
          end
        end
      end

      def travel_back
        simple_stubs.unstub_all!
      end

      private

        def simple_stubs
          @simple_stubs ||= SimpleStubs.new
        end
    end
  end
end
