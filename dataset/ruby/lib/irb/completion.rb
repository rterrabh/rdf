
require "readline"

module IRB
  module InputCompletor # :nodoc:


    ReservedWords = %w[
      BEGIN END
      alias and
      begin break
      case class
      def defined do
      else elsif end ensure
      false for
      if in
      module
      next nil not
      or
      redo rescue retry return
      self super
      then true
      undef unless until
      when while
      yield
    ]

    CompletionProc = proc { |input|
      bind = IRB.conf[:MAIN_CONTEXT].workspace.binding

      case input
      when /^((["'`]).*\2)\.([^.]*)$/
        receiver = $1
        message = Regexp.quote($3)

        candidates = String.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /^(\/[^\/]*\/)\.([^.]*)$/
        receiver = $1
        message = Regexp.quote($2)

        candidates = Regexp.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /^([^\]]*\])\.([^.]*)$/
        receiver = $1
        message = Regexp.quote($2)

        candidates = Array.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /^([^\}]*\})\.([^.]*)$/
        receiver = $1
        message = Regexp.quote($2)

        candidates = Proc.instance_methods.collect{|m| m.to_s}
        candidates |= Hash.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      when /^(:[^:.]*)$/
        if Symbol.respond_to?(:all_symbols)
          sym = $1
          candidates = Symbol.all_symbols.collect{|s| ":" + s.id2name}
          candidates.grep(/^#{Regexp.quote(sym)}/)
        else
          []
        end

      when /^::([A-Z][^:\.\(]*)$/
        receiver = $1
        candidates = Object.constants.collect{|m| m.to_s}
        candidates.grep(/^#{receiver}/).collect{|e| "::" + e}

      when /^([A-Z].*)::([^:.]*)$/
        receiver = $1
        message = Regexp.quote($2)
        begin
          #nodyna <eval-2195> <EV COMPLEX (scope)>
          candidates = eval("#{receiver}.constants.collect{|m| m.to_s}", bind)
          #nodyna <eval-2196> <EV COMPLEX (scope)>
          candidates |= eval("#{receiver}.methods.collect{|m| m.to_s}", bind)
        rescue Exception
          candidates = []
        end
        select_message(receiver, message, candidates, "::")

      when /^(:[^:.]+)(\.|::)([^.]*)$/
        receiver = $1
        sep = $2
        message = Regexp.quote($3)

        candidates = Symbol.instance_methods.collect{|m| m.to_s}
        select_message(receiver, message, candidates, sep)

      when /^(-?(0[dbo])?[0-9_]+(\.[0-9_]+)?([eE]-?[0-9]+)?)(\.|::)([^.]*)$/
        receiver = $1
        sep = $5
        message = Regexp.quote($6)

        begin
          #nodyna <eval-2197> <EV COMPLEX (scope)>
          candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
        rescue Exception
          candidates = []
        end
        select_message(receiver, message, candidates, sep)

      when /^(-?0x[0-9a-fA-F_]+)(\.|::)([^.]*)$/
        receiver = $1
        sep = $2
        message = Regexp.quote($3)

        begin
          #nodyna <eval-2198> <EV COMPLEX (scope)>
          candidates = eval(receiver, bind).methods.collect{|m| m.to_s}
        rescue Exception
          candidates = []
        end
        select_message(receiver, message, candidates, sep)

      when /^(\$[^.]*)$/
        regmessage = Regexp.new(Regexp.quote($1))
        candidates = global_variables.collect{|m| m.to_s}.grep(regmessage)

      when /^([^."].*)(\.|::)([^.]*)$/
        receiver = $1
        sep = $2
        message = Regexp.quote($3)

        #nodyna <eval-2199> <EV COMPLEX (private methods)>
        gv = eval("global_variables", bind).collect{|m| m.to_s}
        #nodyna <eval-2200> <EV COMPLEX (private methods)>
        lv = eval("local_variables", bind).collect{|m| m.to_s}
        #nodyna <eval-2201> <EV COMPLEX (private methods)>
        iv = eval("instance_variables", bind).collect{|m| m.to_s}
        #nodyna <eval-2202> <EV COMPLEX (private methods)>
        cv = eval("self.class.constants", bind).collect{|m| m.to_s}

        if (gv | lv | iv | cv).include?(receiver) or /^[A-Z]/ =~ receiver && /\./ !~ receiver
          begin
            candidates = []
            #nodyna <eval-2203> <EV COMPLEX (change-prone variables)>
            rec = eval(receiver, bind)
            if sep == "::" and rec.kind_of?(Module)
              candidates = rec.constants.collect{|m| m.to_s}
            end
            candidates |= rec.methods.collect{|m| m.to_s}
          rescue Exception
            candidates = []
          end
        else
          candidates = []
          ObjectSpace.each_object(Module){|m|
            begin
              name = m.name
            rescue Exception
              name = ""
            end
            begin
              next if name != "IRB::Context" and
                /^(IRB|SLex|RubyLex|RubyToken)/ =~ name
            rescue Exception
              next
            end
            candidates.concat m.instance_methods(false).collect{|x| x.to_s}
          }
          candidates.sort!
          candidates.uniq!
        end
        select_message(receiver, message, candidates, sep)

      when /^\.([^.]*)$/

        receiver = ""
        message = Regexp.quote($1)

        candidates = String.instance_methods(true).collect{|m| m.to_s}
        select_message(receiver, message, candidates)

      else
        #nodyna <eval-2204> <EV COMPLEX (private methods)>
        candidates = eval("methods | private_methods | local_variables | instance_variables | self.class.constants", bind).collect{|m| m.to_s}

        (candidates|ReservedWords).grep(/^#{Regexp.quote(input)}/)
      end
    }

    Operators = %w[% & * ** + - / < << <= <=> == === =~ > >= >> [] []= ^ ! != !~]

    def self.select_message(receiver, message, candidates, sep = ".")
      candidates.grep(/^#{message}/).collect do |e|
        case e
        when /^[a-zA-Z_]/
          receiver + sep + e
        when /^[0-9]/
        when *Operators
        end
      end
    end
  end
end

if Readline.respond_to?("basic_word_break_characters=")
  Readline.basic_word_break_characters= " \t\n`><=;|&{("
end
Readline.completion_append_character = nil
Readline.completion_proc = IRB::InputCompletor::CompletionProc
