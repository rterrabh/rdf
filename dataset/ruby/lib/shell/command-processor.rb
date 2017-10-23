
require "e2mmap"
require "thread"

require "shell/error"
require "shell/filter"
require "shell/system-command"
require "shell/builtin-command"

class Shell
  class CommandProcessor

    m = [:initialize, :expand_path]
    if Object.methods.first.kind_of?(String)
      NoDelegateMethods = m.collect{|x| x.id2name}
    else
      NoDelegateMethods = m
    end

    def self.initialize

      install_builtin_commands

      for m in CommandProcessor.instance_methods(false) - NoDelegateMethods
        add_delegate_command_to_shell(m)
      end

      def self.method_added(id)
        add_delegate_command_to_shell(id)
      end
    end

    def self.run_config
      begin
        load File.expand_path("~/.rb_shell") if ENV.key?("HOME")
      rescue LoadError, Errno::ENOENT
      rescue
        print "load error: #{rc}\n"
        print $!.class, ": ", $!, "\n"
        for err in $@[0, $@.size - 2]
          print "\t", err, "\n"
        end
      end
    end

    def initialize(shell)
      @shell = shell
      @system_commands = {}
    end

    def expand_path(path)
      @shell.expand_path(path)
    end

    def foreach(path = nil, *rs)
      path = "." unless path
      path = expand_path(path)

      if File.directory?(path)
        Dir.foreach(path){|fn| yield fn}
      else
        IO.foreach(path, *rs){|l| yield l}
      end
    end

    def open(path, mode = nil, perm = 0666, &b)
      path = expand_path(path)
      if File.directory?(path)
        Dir.open(path, &b)
      else
        if @shell.umask
          f = File.open(path, mode, perm)
          File.chmod(perm & ~@shell.umask, path)
          if block_given?
            f.each(&b)
          end
          f
        else
          File.open(path, mode, perm, &b)
        end
      end
    end

    def unlink(path)
      @shell.check_point

      path = expand_path(path)
      if File.directory?(path)
        Dir.unlink(path)
      else
        IO.unlink(path)
      end
      Void.new(@shell)
    end

    alias top_level_test test
    def test(command, file1, file2=nil)
      file1 = expand_path(file1)
      file2 = expand_path(file2) if file2
      command = command.id2name if command.kind_of?(Symbol)

      case command
      when Integer
        if file2
          top_level_test(command, file1, file2)
        else
          top_level_test(command, file1)
        end
      when String
        if command.size == 1
          if file2
            top_level_test(command, file1, file2)
          else
            top_level_test(command, file1)
          end
        else
          if file2
            #nodyna <send-2136> <SD COMPLEX (change-prone variables)>
            FileTest.send(command, file1, file2)
          else
            #nodyna <send-2137> <SD COMPLEX (change-prone variables)>
            FileTest.send(command, file1)
          end
        end
      end
    end
    alias [] test

    def mkdir(*path)
      @shell.check_point
      notify("mkdir #{path.join(' ')}")

      perm = nil
      if path.last.kind_of?(Integer)
        perm = path.pop
      end
      for dir in path
        d = expand_path(dir)
        if perm
          Dir.mkdir(d, perm)
        else
          Dir.mkdir(d)
        end
        File.chmod(d, 0666 & ~@shell.umask) if @shell.umask
      end
      Void.new(@shell)
    end

    def rmdir(*path)
      @shell.check_point
      notify("rmdir #{path.join(' ')}")

      for dir in path
        Dir.rmdir(expand_path(dir))
      end
      Void.new(@shell)
    end

    def system(command, *opts)
      if opts.empty?
        if command =~ /\*|\?|\{|\}|\[|\]|<|>|\(|\)|~|&|\||\\|\$|;|'|`|"|\n/
          return SystemCommand.new(@shell, find_system_command("sh"), "-c", command)
        else
          command, *opts = command.split(/\s+/)
        end
      end
      SystemCommand.new(@shell, find_system_command(command), *opts)
    end

    def rehash
      @system_commands = {}
    end

    def check_point # :nodoc:
      @shell.process_controller.wait_all_jobs_execution
    end
    alias finish_all_jobs check_point # :nodoc:

    def transact(&block)
      begin
        #nodyna <instance_eval-2138> <IEV COMPLEX (block execution)>
        @shell.instance_eval(&block)
      ensure
        check_point
      end
    end

    def out(dev = STDOUT, &block)
      dev.print transact(&block)
    end

    def echo(*strings)
      Echo.new(@shell, *strings)
    end

    def cat(*filenames)
      Cat.new(@shell, *filenames)
    end

    def glob(pattern)
      Glob.new(@shell, pattern)
    end

    def append(to, filter)
      case to
      when String
        AppendFile.new(@shell, to, filter)
      when IO
        AppendIO.new(@shell, to, filter)
      else
        Shell.Fail Error::CantApplyMethod, "append", to.class
      end
    end

    def tee(file)
      Tee.new(@shell, file)
    end

    def concat(*jobs)
      Concat.new(@shell, *jobs)
    end

    def notify(*opts)
      Shell.notify(*opts) {|mes|
        yield mes if iterator?

        mes.gsub!("%pwd", "#{@cwd}")
        mes.gsub!("%cwd", "#{@cwd}")
      }
    end

    def find_system_command(command)
      return command if /^\// =~ command
      case path = @system_commands[command]
      when String
        if exists?(path)
          return path
        else
          Shell.Fail Error::CommandNotFound, command
        end
      when false
        Shell.Fail Error::CommandNotFound, command
      end

      for p in @shell.system_path
        path = join(p, command)
        begin
          st = File.stat(path)
        rescue SystemCallError
          next
        else
          next unless st.executable? and !st.directory?
          @system_commands[command] = path
          return path
        end
      end
      @system_commands[command] = false
      Shell.Fail Error::CommandNotFound, command
    end

    def self.def_system_command(command, path = command)
      begin
        #nodyna <eval-2139> <EV COMPLEX (method definition)>
        eval((d = %Q[def #{command}(*opts)
                  SystemCommand.new(@shell, '#{path}', *opts)
               end]), nil, __FILE__, __LINE__ - 1)
      rescue SyntaxError
        Shell.notify "warn: Can't define #{command} path: #{path}."
      end
      Shell.notify "Define #{command} path: #{path}.", Shell.debug?
      Shell.notify("Definition of #{command}: ", d,
             Shell.debug.kind_of?(Integer) && Shell.debug > 1)
    end

    def self.undef_system_command(command)
      command = command.id2name if command.kind_of?(Symbol)
      remove_method(command)
      #nodyna <module_eval-2140> <ME MODERATE (block execution)>
      Shell.module_eval{remove_method(command)}
      #nodyna <module_eval-2141> <ME MODERATE (block execution)>
      Filter.module_eval{remove_method(command)}
      self
    end

    @alias_map = {}
    def self.alias_map
      @alias_map
    end
    def self.alias_command(ali, command, *opts)
      ali = ali.id2name if ali.kind_of?(Symbol)
      command = command.id2name if command.kind_of?(Symbol)
      begin
        if iterator?
          @alias_map[ali.intern] = proc

          #nodyna <eval-2142> <EV COMPLEX (method definition)>
          eval((d = %Q[def #{ali}(*opts)
                          @shell.__send__(:#{command},
                                          *(CommandProcessor.alias_map[:#{ali}].call *opts))
                        end]), nil, __FILE__, __LINE__ - 1)

        else
           args = opts.collect{|opt| '"' + opt + '"'}.join(",")
           #nodyna <eval-2143> <EV COMPLEX (method definition)>
           eval((d = %Q[def #{ali}(*opts)
                          @shell.__send__(:#{command}, #{args}, *opts)
                        end]), nil, __FILE__, __LINE__ - 1)
        end
      rescue SyntaxError
        Shell.notify "warn: Can't alias #{ali} command: #{command}."
        Shell.notify("Definition of #{ali}: ", d)
        raise
      end
      Shell.notify "Define #{ali} command: #{command}.", Shell.debug?
      Shell.notify("Definition of #{ali}: ", d,
             Shell.debug.kind_of?(Integer) && Shell.debug > 1)
      self
    end

    def self.unalias_command(ali)
      ali = ali.id2name if ali.kind_of?(Symbol)
      @alias_map.delete ali.intern
      undef_system_command(ali)
    end

    def self.def_builtin_commands(delegation_class, command_specs)
      for meth, args in command_specs
        arg_str = args.collect{|arg| arg.downcase}.join(", ")
        call_arg_str = args.collect{
          |arg|
          case arg
          when /^(FILENAME.*)$/
            format("expand_path(%s)", $1.downcase)
          when /^(\*FILENAME.*)$/
            $1.downcase + '.collect{|fn| expand_path(fn)}'
          else
            arg
          end
        }.join(", ")
        d = %Q[def #{meth}(#{arg_str})
                 end]
        Shell.notify "Define #{meth}(#{arg_str})", Shell.debug?
        Shell.notify("Definition of #{meth}: ", d,
                     Shell.debug.kind_of?(Integer) && Shell.debug > 1)
        #nodyna <eval-2144> <EV COMPLEX (method definition)>
        eval d
      end
    end

    def self.install_system_commands(pre = "sys_")
      defined_meth = {}
      for m in Shell.methods
        defined_meth[m] = true
      end
      sh = Shell.new
      for path in Shell.default_system_path
        next unless sh.directory? path
        sh.cd path
        sh.foreach do
          |cn|
          if !defined_meth[pre + cn] && sh.file?(cn) && sh.executable?(cn)
            command = (pre + cn).gsub(/\W/, "_").sub(/^([0-9])/, '_\1')
            begin
              def_system_command(command, sh.expand_path(cn))
            rescue
              Shell.notify "warn: Can't define #{command} path: #{cn}"
            end
            defined_meth[command] = command
          end
        end
      end
    end

    def self.add_delegate_command_to_shell(id) # :nodoc:
      id = id.intern if id.kind_of?(String)
      name = id.id2name
      if Shell.method_defined?(id)
        Shell.notify "warn: override definition of Shell##{name}."
        Shell.notify "warn: alias Shell##{name} to Shell##{name}_org.\n"
        #nodyna <module_eval-2145> <ME COMPLEX (define methods)>
        Shell.module_eval "alias #{name}_org #{name}"
      end
      Shell.notify "method added: Shell##{name}.", Shell.debug?
      #nodyna <module_eval-2146> <ME COMPLEX (define methods)>
      Shell.module_eval(%Q[def #{name}(*args, &block)
                            begin
                              @command_processor.__send__(:#{name}, *args, &block)
                            rescue Exception
                              $@.delete_if{|s| /:in `__getobj__'$/ =~ s} #`
                              $@.delete_if{|s| /^\\(eval\\):/ =~ s}
                            raise
                            end
                          end], __FILE__, __LINE__)

      if Shell::Filter.method_defined?(id)
        Shell.notify "warn: override definition of Shell::Filter##{name}."
        Shell.notify "warn: alias Shell##{name} to Shell::Filter##{name}_org."
        #nodyna <module_eval-2148> <ME COMPLEX (define methods)>
        Filter.module_eval "alias #{name}_org #{name}"
      end
      Shell.notify "method added: Shell::Filter##{name}.", Shell.debug?
      #nodyna <module_eval-2149> <ME COMPLEX (define methods)>
      Filter.module_eval(%Q[def #{name}(*args, &block)
                            begin
                              self | @shell.__send__(:#{name}, *args, &block)
                            rescue Exception
                              $@.delete_if{|s| /:in `__getobj__'$/ =~ s} #`
                              $@.delete_if{|s| /^\\(eval\\):/ =~ s}
                            raise
                            end
                          end], __FILE__, __LINE__)
    end

    def self.install_builtin_commands
      normal_delegation_file_methods = [
        ["atime", ["FILENAME"]],
        ["basename", ["fn", "*opts"]],
        ["chmod", ["mode", "*FILENAMES"]],
        ["chown", ["owner", "group", "*FILENAME"]],
        ["ctime", ["FILENAMES"]],
        ["delete", ["*FILENAMES"]],
        ["dirname", ["FILENAME"]],
        ["ftype", ["FILENAME"]],
        ["join", ["*items"]],
        ["link", ["FILENAME_O", "FILENAME_N"]],
        ["lstat", ["FILENAME"]],
        ["mtime", ["FILENAME"]],
        ["readlink", ["FILENAME"]],
        ["rename", ["FILENAME_FROM", "FILENAME_TO"]],
        ["split", ["pathname"]],
        ["stat", ["FILENAME"]],
        ["symlink", ["FILENAME_O", "FILENAME_N"]],
        ["truncate", ["FILENAME", "length"]],
        ["utime", ["atime", "mtime", "*FILENAMES"]]]

      def_builtin_commands(File, normal_delegation_file_methods)
      alias_method :rm, :delete

      def_builtin_commands(FileTest,
                   FileTest.singleton_methods(false).collect{|m| [m, ["FILENAME"]]})

    end

  end
end
