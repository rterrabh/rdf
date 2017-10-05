#
#   irb/workspace-binding.rb -
#   	$Release Version: 0.9.6$
#   	$Revision$
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#
module IRB # :nodoc:
  class WorkSpace
    # Creates a new workspace.
    #
    # set self to main if specified, otherwise
    # inherit main from TOPLEVEL_BINDING.
    def initialize(*main)
      if main[0].kind_of?(Binding)
        @binding = main.shift
      elsif IRB.conf[:SINGLE_IRB]
        @binding = TOPLEVEL_BINDING
      else
        case IRB.conf[:CONTEXT_MODE]
        when 0	# binding in proc on TOPLEVEL_BINDING
          #nodyna <ID:eval-104> <EV COMPLEX (scope)>
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

            #nodyna <ID:const_set-64> <CS TRIVIAL (static values)>
            IRB.const_set(:BINDING_QUEUE, SizedQueue.new(1))
            Thread.abort_on_exception = true
            Thread.start do
              #nodyna <ID:eval-105> <EV COMPLEX (scope)>
              eval "require \"irb/ws-for-case-2\"", TOPLEVEL_BINDING, __FILE__, __LINE__
            end
            Thread.pass
          end
          @binding = BINDING_QUEUE.pop

        when 3	# binding in function on TOPLEVEL_BINDING(default)
          #nodyna <ID:eval-106> <EV COMPLEX (change-prone variables)>
          @binding = eval("def irb_binding; private; binding; end; irb_binding",
                          TOPLEVEL_BINDING,
                          __FILE__,
                          __LINE__ - 3)
        end
      end
      if main.empty?
        #nodyna <ID:eval-107> <EV COMPLEX (scope)>
        @main = eval("self", @binding)
      else
        @main = main[0]
        IRB.conf[:__MAIN__] = @main
        case @main
        when Module
          #nodyna <ID:eval-108> <EV COMPLEX (scope)>
          @binding = eval("IRB.conf[:__MAIN__].module_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
        else
          begin
            #nodyna <ID:eval-176> <EV COMPLEX (scope)>
            #nodyna <ID:instance_eval-176> <IEV COMPLEX (private access)>
            @binding = eval("IRB.conf[:__MAIN__].instance_eval('binding', __FILE__, __LINE__)", @binding, __FILE__, __LINE__)
          rescue TypeError
            IRB.fail CantChangeBinding, @main.inspect
          end
        end
      end
      #nodyna <ID:eval-110> <EV COMPLEX (scope)>
      eval("_=nil", @binding)
    end

    # The Binding of this workspace
    attr_reader :binding
    # The top-level workspace of this context, also available as
    # <code>IRB.conf[:__MAIN__]</code>
    attr_reader :main

    # Evaluate the given +statements+ within the  context of this workspace.
    def evaluate(context, statements, file = __FILE__, line = __LINE__)
      #nodyna <ID:eval-111> <EV COMPLEX (change-prone variables)>
      eval(statements, @binding, file, line)
    end

    # error message manipulator
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
