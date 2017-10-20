if Time.local(2010).zone != Marshal.load(Marshal.dump(Time.local(2010))).zone
  class Time
    class << self
      alias_method :_load_without_zone, :_load
      def _load(marshaled_time)
        time = _load_without_zone(marshaled_time)
        #nodyna <instance_eval-1097> <IEV COMPLEX (private access)>
        time.instance_eval do
          if zone = defined?(@_zone) && remove_instance_variable('@_zone')
            ary = to_a
            ary[0] += subsec if ary[0] == sec
            ary[-1] = zone
            utc? ? Time.utc(*ary) : Time.local(*ary)
          else
            self
          end
        end
      end
    end

    alias_method :_dump_without_zone, :_dump
    def _dump(*args)
      obj = dup
      #nodyna <instance_variable_set-1098> <IVS MODERATE (private access)>
      obj.instance_variable_set('@_zone', zone)
      #nodyna <send-1099> <SD EASY (private methods)>
      obj.send :_dump_without_zone, *args
    end
  end
end
