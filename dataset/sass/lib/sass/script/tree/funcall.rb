require 'sass/script/functions'
require 'sass/util/normalized_map'

module Sass::Script::Tree
  class Funcall < Node
    attr_reader :name

    attr_reader :args

    attr_reader :keywords

    attr_accessor :splat

    attr_accessor :kwarg_splat

    def initialize(name, args, keywords, splat, kwarg_splat)
      @name = name
      @args = args
      @keywords = keywords
      @splat = splat
      @kwarg_splat = kwarg_splat
      super()
    end

    def inspect
      args = @args.map {|a| a.inspect}.join(', ')
      keywords = Sass::Util.hash_to_a(@keywords.as_stored).
          map {|k, v| "$#{k}: #{v.inspect}"}.join(', ')
      if self.splat
        splat = args.empty? && keywords.empty? ? "" : ", "
        splat = "#{splat}#{self.splat.inspect}..."
        splat = "#{splat}, #{kwarg_splat.inspect}..." if kwarg_splat
      end
      "#{name}(#{args}#{', ' unless args.empty? || keywords.empty?}#{keywords}#{splat})"
    end

    def to_sass(opts = {})
      arg_to_sass = lambda do |arg|
        sass = arg.to_sass(opts)
        sass = "(#{sass})" if arg.is_a?(Sass::Script::Tree::ListLiteral) && arg.separator == :comma
        sass
      end

      args = @args.map(&arg_to_sass)
      keywords = Sass::Util.hash_to_a(@keywords.as_stored).
        map {|k, v| "$#{dasherize(k, opts)}: #{arg_to_sass[v]}"}

      if self.splat
        splat = "#{arg_to_sass[self.splat]}..."
        kwarg_splat = "#{arg_to_sass[self.kwarg_splat]}..." if self.kwarg_splat
      end

      arglist = [args, splat, keywords, kwarg_splat].flatten.compact.join(', ')
      "#{dasherize(name, opts)}(#{arglist})"
    end

    def children
      res = @args + @keywords.values
      res << @splat if @splat
      res << @kwarg_splat if @kwarg_splat
      res
    end

    def deep_copy
      node = dup
      #nodyna <instance_variable_set-3021> <IVS MODERATE (private access)>
      node.instance_variable_set('@args', args.map {|a| a.deep_copy})
      copied_keywords = Sass::Util::NormalizedMap.new
      @keywords.as_stored.each {|k, v| copied_keywords[k] = v.deep_copy}
      #nodyna <instance_variable_set-3022> <IVS MODERATE (private access)>
      node.instance_variable_set('@keywords', copied_keywords)
      node
    end

    protected

    def _perform(environment)
      args = Sass::Util.enum_with_index(@args).
        map {|a, i| perform_arg(a, environment, signature && signature.args[i])}
      keywords = Sass::Util.map_hash(@keywords) do |k, v|
        [k, perform_arg(v, environment, k.tr('-', '_'))]
      end
      splat = Sass::Tree::Visitors::Perform.perform_splat(
        @splat, keywords, @kwarg_splat, environment)
      if (fn = environment.function(@name))
        return without_original(perform_sass_fn(fn, args, splat, environment))
      end

      args = construct_ruby_args(ruby_name, args, splat, environment)

      if Sass::Script::Functions.callable?(ruby_name)
        local_environment = Sass::Environment.new(environment.global_env, environment.options)
        local_environment.caller = Sass::ReadOnlyEnvironment.new(environment, environment.options)
        result = opts(Sass::Script::Functions::EvaluationContext.new(
          #nodyna <send-3023> <SD COMPLEX (change-prone variables)>
          local_environment).send(ruby_name, *args))
        without_original(result)
      else
        opts(to_literal(args))
      end
    rescue ArgumentError => e
      reformat_argument_error(e)
    end

    def to_literal(args)
      to_value(args)
    end

    def to_value(args)
      Sass::Script::Value::String.new("#{name}(#{args.join(', ')})")
    end

    private

    def ruby_name
      @ruby_name ||= @name.tr('-', '_')
    end

    def perform_arg(argument, environment, name)
      return argument if signature && signature.delayed_args.include?(name)
      argument.perform(environment)
    end

    def signature
      @signature ||= Sass::Script::Functions.signature(name.to_sym, @args.size, @keywords.size)
    end

    def without_original(value)
      return value unless value.is_a?(Sass::Script::Value::Number)
      value = value.dup
      value.original = nil
      value
    end

    def construct_ruby_args(name, args, splat, environment)
      args += splat.to_a if splat

      old_keywords_accessed = splat.keywords_accessed
      keywords = splat.keywords
      splat.keywords_accessed = old_keywords_accessed

      unless (signature = Sass::Script::Functions.signature(name.to_sym, args.size, keywords.size))
        return args if keywords.empty?
        raise Sass::SyntaxError.new("Function #{name} doesn't support keyword arguments")
      end

      if signature.var_kwargs && !signature.var_args && args.size > signature.args.size
        raise Sass::SyntaxError.new(
          "#{args[signature.args.size].inspect} is not a keyword argument for `#{name}'")
      elsif keywords.empty?
        return args
      end

      argnames = signature.args[args.size..-1] || []
      deprecated_argnames = (signature.deprecated && signature.deprecated[args.size..-1]) || []
      args = args + argnames.zip(deprecated_argnames).map do |(argname, deprecated_argname)|
        if keywords.has_key?(argname)
          keywords.delete(argname)
        elsif deprecated_argname && keywords.has_key?(deprecated_argname)
          deprecated_argname = keywords.denormalize(deprecated_argname)
          Sass::Util.sass_warn("DEPRECATION WARNING: The `$#{deprecated_argname}' argument for " +
            "`#{@name}()' has been renamed to `$#{argname}'.")
          keywords.delete(deprecated_argname)
        else
          raise Sass::SyntaxError.new("Function #{name} requires an argument named $#{argname}")
        end
      end

      if keywords.size > 0
        if signature.var_kwargs
          args << keywords.to_hash
        else
          argname = keywords.keys.sort.first
          if signature.args.include?(argname)
            raise Sass::SyntaxError.new(
              "Function #{name} was passed argument $#{argname} both by position and by name")
          else
            raise Sass::SyntaxError.new(
              "Function #{name} doesn't have an argument named $#{argname}")
          end
        end
      end

      args
    end

    def perform_sass_fn(function, args, splat, environment)
      Sass::Tree::Visitors::Perform.perform_arguments(function, args, splat, environment) do |env|
        env.caller = Sass::Environment.new(environment)

        val = catch :_sass_return do
          function.tree.each {|c| Sass::Tree::Visitors::Perform.visit(c, env)}
          raise Sass::SyntaxError.new("Function #{@name} finished without @return")
        end
        val
      end
    end

    def reformat_argument_error(e)
      message = e.message

      if Sass::Util.rbx?
        if e.message =~ /^method '([^']+)': given (\d+), expected (\d+)/
          error_name, given, expected = $1, $2, $3
          raise e if error_name != ruby_name || e.backtrace[0] !~ /:in `_perform'$/
          message = "wrong number of arguments (#{given} for #{expected})"
        end
      elsif Sass::Util.jruby?
        if Sass::Util.jruby1_6?
          should_maybe_raise = e.message =~ /^wrong number of arguments \((\d+) for (\d+)\)/ &&
            e.backtrace[0] !~ /:in `(block in )?#{ruby_name}'$/
        else
          should_maybe_raise =
            e.message =~ /^wrong number of arguments calling `[^`]+` \((\d+) for (\d+)\)/
          given, expected = $1, $2
        end

        if should_maybe_raise
          trace = e.backtrace.dup
          raise e if !Sass::Util.jruby1_6? && trace.shift !~ /:in `__send__'$/

          if !(trace[0] =~ /:in `send'$/ && trace[1] =~ /:in `_perform'$/)
            raise e
          elsif !Sass::Util.jruby1_6?
            message = "wrong number of arguments (#{given} for #{expected})"
          end
        end
      elsif e.message =~ /^wrong number of arguments \(\d+ for \d+\)/ &&
          e.backtrace[0] !~ /:in `(block in )?#{ruby_name}'$/
        raise e
      end
      raise Sass::SyntaxError.new("#{message} for `#{name}'")
    end
  end
end
