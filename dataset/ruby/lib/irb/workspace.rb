module IRB # :nodoc:
  class WorkSpace
    def initialize(*main)
      if main[0].kind_of?(Binding)
        @binding = main.shift
      elsif IRB.conf[:SINGLE_IRB]
        @binding = TOPLEVEL_BINDING
      else
        case IRB.conf[:CONTEXT_MODE]
        when 0	# binding in proc on TOPLEVEL_BINDING
          #nodyna <eval-2180> <EV COMPLEX (scope)>
          @binding = eval("proc{binding}.call",
                          TOPLEVEL_BINDING,
                          __FILE__,
                          __LINE__)
        when 1	# binding in loaded file
          require "tempfile"
          f = Tempfile.open("irb-binding")
          f.print <<EOF
      $binding = binding
EOF
          f.close
          load f.path
          @binding = $binding

        when 2	# binding in loaded file(thread use)
          unless defined? BINDING_QUEUE
            require "thread"

            #nodyna <const_set-2181> <CS TRIVIAL (static values)>
            IRB.const_set(:BINDING_QUEUE, SizedQueue.new(1))
            Thread.abort_on_exception = true
            Thread.start do
              #nodyna <eval-2182> <EV COMPLEX (scope)>
              eval "require \"irb/ws-for-case-2\"", TOPLEVEL_BINDING, __FILE__, __LINE__
            end
            Thread.pass
          end
          @binding = BINDING_QUEUE.pop

        when 3	# binding in function on TOPLEVEL_BINDING(default)
          #nodyna <eval-2183> <EV COMPLEX (change-prone variables)>
          @binding = eval("def irb_binding; private; binding; end; irb_binding",
                          TOPLEVEL_BINDING,
                          __FILE__,
                          __LINE__ - 3)
        end
      end
      if main.empty?
        #nodyna <eval-2184> <EV COMPLEX (scope)>
        @main = eval("self", @binding)
      else
        @main = main[0]
        IRB.conf[:__MAIN__] = @main
        case @main
        when Module
          #nodyna <eval-2185> <EV COMPLEX (scope)>
          #nodyna <module_eval-2186> <not yet classified>
          @binding = eval("IRB.conf[:__MAIN__].module_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
        else
          begin
            #nodyna <eval-2187> <EV COMPLEX (scope)>
            #nodyna <instance_eval-2188> <IEV COMPLEX (private access)>
            @binding = eval("IRB.conf[:__MAIN__].instance_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
          rescue TypeError
            IRB.fail CantChangeBinding, @main.inspect
          end
        end
      end
      #nodyna <eval-2189> <EV COMPLEX (scope)>
      eval("_=nil", @binding)
    end

    attr_reader :binding
    attr_reader :main

    def evaluate(context, statements, file = __FILE__, line = __LINE__)
      #nodyna <eval-2190> <EV COMPLEX (change-prone variables)>
      eval(statements, @binding, file, line)
    end

    def filter_backtrace(bt)
      case IRB.conf[:CONTEXT_MODE]
      when 0
        return nil if bt =~ /\(irb_local_binding\)/
      when 1
        if(bt =~ %r!/tmp/irb-binding! or
            bt =~ %r!irb/.*\.rb! or
            bt =~ /irb\.rb/)
          return nil
        end
      when 2
        return nil if bt =~ /irb\/.*\.rb/
        return nil if bt =~ /irb\.rb/
      when 3
        return nil if bt =~ /irb\/.*\.rb/
        return nil if bt =~ /irb\.rb/
        bt = bt.sub(/:\s*in `irb_binding'/, '')
      end
      bt
    end

    def IRB.delete_caller
    end
  end
end
