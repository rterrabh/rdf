
require 'rbconfig'


module Rake::AltSystem # :nodoc: all
  WINDOWS = RbConfig::CONFIG["host_os"] =~
    %r!(msdos|mswin|djgpp|mingw|[Ww]indows)!

  class << self
    def define_module_function(name, &block)
      #nodyna <define_method-2040> <DM MODERATE (events)>
      define_method(name, &block)
      module_function(name)
    end
  end

  if WINDOWS && RUBY_VERSION < "1.9.0"
    RUNNABLE_EXTS = %w[com exe bat cmd]
    RUNNABLE_PATTERN = %r!\.(#{RUNNABLE_EXTS.join('|')})\Z!i

    define_module_function :kernel_system, &Kernel.method(:system)
    define_module_function :kernel_backticks, &Kernel.method(:'`')

    module_function

    def repair_command(cmd)
      "call " + (
        if cmd =~ %r!\A\s*\".*?\"!
          cmd
        elsif match = cmd.match(%r!\A\s*(\S+)!)
          if match[1] =~ %r!/!
            %Q!"#{match[1]}"! + match.post_match
          else
            cmd
          end
        else
          cmd
        end
      )
    end

    def find_runnable(file)
      if file =~ RUNNABLE_PATTERN
        file
      else
        RUNNABLE_EXTS.each { |ext|
          test = "#{file}.#{ext}"
          return test if File.exist?(test)
        }
        nil
      end
    end

    def system(cmd, *args)
      repaired = (
        if args.empty?
          [repair_command(cmd)]
        elsif runnable = find_runnable(cmd)
          [File.expand_path(runnable), *args]
        else
          [cmd, *args]
        end
      )
      kernel_system(*repaired)
    end

    def backticks(cmd)
      kernel_backticks(repair_command(cmd))
    end

    define_module_function :'`', &method(:backticks)
  else
    define_module_function :system, &Kernel.method(:system)
    define_module_function :backticks, &Kernel.method(:'`')
    define_module_function :'`', &Kernel.method(:'`')
  end
end
