#
#   fork.rb -
#   	$Release Version: 0.9.6 $
#   	$Revision$
#   	by Keiju ISHITSUKA(keiju@ruby-lang.org)
#
# --
#
#
#


# :stopdoc:
module IRB
  module ExtendCommand
    class Fork<Nop
      def execute
        #nodyna <ID:send-133> <SD TRIVIAL (public methods)>
        pid = send ExtendCommand.irb_original_method_name("fork")
        unless pid
          class << self
            alias_method :exit, ExtendCommand.irb_original_method_name('exit')
          end
          if iterator?
            begin
              yield
            ensure
              exit
            end
          end
        end
        pid
      end
    end
  end
end
# :startdoc:


