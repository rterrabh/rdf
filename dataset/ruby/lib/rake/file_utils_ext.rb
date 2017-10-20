require 'rake/file_utils'

module Rake
  module FileUtilsExt
    include FileUtils

    class << self
      attr_accessor :verbose_flag, :nowrite_flag
    end

    DEFAULT = Object.new

    FileUtilsExt.verbose_flag = DEFAULT
    FileUtilsExt.nowrite_flag = false

    FileUtils.commands.each do |name|
      opts = FileUtils.options_of name
      default_options = []
      if opts.include?("verbose")
        default_options << ':verbose => FileUtilsExt.verbose_flag'
      end
      if opts.include?("noop")
        default_options << ':noop => FileUtilsExt.nowrite_flag'
      end

      next if default_options.empty?
      #nodyna <module_eval-2035> <ME COMPLEX (define methods)>
      module_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def #{name}( *args, &block )
        super(
          *rake_merge_option(args,
            ), &block)
      end
      EOS
    end

    def verbose(value=nil)
      oldvalue = FileUtilsExt.verbose_flag
      FileUtilsExt.verbose_flag = value unless value.nil?
      if block_given?
        begin
          yield
        ensure
          FileUtilsExt.verbose_flag = oldvalue
        end
      end
      FileUtilsExt.verbose_flag
    end

    def nowrite(value=nil)
      oldvalue = FileUtilsExt.nowrite_flag
      FileUtilsExt.nowrite_flag = value unless value.nil?
      if block_given?
        begin
          yield
        ensure
          FileUtilsExt.nowrite_flag = oldvalue
        end
      end
      oldvalue
    end

    def when_writing(msg=nil)
      if FileUtilsExt.nowrite_flag
        $stderr.puts "DRYRUN: #{msg}" if msg
      else
        yield
      end
    end

    def rake_merge_option(args, defaults)
      if Hash === args.last
        defaults.update(args.last)
        args.pop
      end
      args.push defaults
      args
    end

    def rake_output_message(message)
      $stderr.puts(message)
    end

    def rake_check_options(options, *optdecl)
      h = options.dup
      optdecl.each do |name|
        h.delete name
      end
      raise ArgumentError, "no such option: #{h.keys.join(' ')}" unless
        h.empty?
    end

    extend self
  end
end
