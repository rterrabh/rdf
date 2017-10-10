module Rake

  module TaskManager
    attr_accessor :last_description


    alias :last_comment :last_description # :nodoc: Backwards compatibility

    def initialize # :nodoc:
      super
      @tasks = Hash.new
      @rules = Array.new
      @scope = Scope.make
      @last_description = nil
    end

    def create_rule(*args, &block) # :nodoc:
      pattern, args, deps = resolve_args(args)
      pattern = Regexp.new(Regexp.quote(pattern) + '$') if String === pattern
      @rules << [pattern, args, deps, block]
    end

    def define_task(task_class, *args, &block) # :nodoc:
      task_name, arg_names, deps = resolve_args(args)

      original_scope = @scope
      if String === task_name and
         not task_class.ancestors.include? Rake::FileTask then
        task_name, *definition_scope = *(task_name.split(":").reverse)
        @scope = Scope.make(*(definition_scope + @scope.to_a))
      end

      task_name = task_class.scope_name(@scope, task_name)
      deps = [deps] unless deps.respond_to?(:to_ary)
      deps = deps.map { |d| Rake.from_pathname(d).to_s }
      task = intern(task_class, task_name)
      task.set_arg_names(arg_names) unless arg_names.empty?
      if Rake::TaskManager.record_task_metadata
        add_location(task)
        task.add_description(get_description(task))
      end
      task.enhance(deps, &block)
    ensure
      @scope = original_scope
    end

    def intern(task_class, task_name)
      @tasks[task_name.to_s] ||= task_class.new(task_name, self)
    end

    def [](task_name, scopes=nil)
      task_name = task_name.to_s
      self.lookup(task_name, scopes) or
        enhance_with_matching_rule(task_name) or
        synthesize_file_task(task_name) or
        fail "Don't know how to build task '#{task_name}'"
    end

    def synthesize_file_task(task_name) # :nodoc:
      return nil unless File.exist?(task_name)
      define_task(Rake::FileTask, task_name)
    end

    def resolve_args(args)
      if args.last.is_a?(Hash)
        deps = args.pop
        resolve_args_with_dependencies(args, deps)
      else
        resolve_args_without_dependencies(args)
      end
    end

    def resolve_args_without_dependencies(args)
      task_name = args.shift
      if args.size == 1 && args.first.respond_to?(:to_ary)
        arg_names = args.first.to_ary
      else
        arg_names = args
      end
      [task_name, arg_names, []]
    end
    private :resolve_args_without_dependencies

    def resolve_args_with_dependencies(args, hash) # :nodoc:
      fail "Task Argument Error" if hash.size != 1
      key, value = hash.map { |k, v| [k, v] }.first
      if args.empty?
        task_name = key
        arg_names = []
        deps = value || []
      else
        task_name = args.shift
        arg_names = key
        deps = value
      end
      deps = [deps] unless deps.respond_to?(:to_ary)
      [task_name, arg_names, deps]
    end
    private :resolve_args_with_dependencies

    def enhance_with_matching_rule(task_name, level=0)
      fail Rake::RuleRecursionOverflowError,
        "Rule Recursion Too Deep" if level >= 16
      @rules.each do |pattern, args, extensions, block|
        if pattern.match(task_name)
          task = attempt_rule(task_name, args, extensions, block, level)
          return task if task
        end
      end
      nil
    rescue Rake::RuleRecursionOverflowError => ex
      ex.add_target(task_name)
      fail ex
    end

    def tasks
      @tasks.values.sort_by { |t| t.name }
    end

    def tasks_in_scope(scope)
      prefix = scope.path
      tasks.select { |t|
        /^#{prefix}:/ =~ t.name
      }
    end

    def clear
      @tasks.clear
      @rules.clear
    end

    def lookup(task_name, initial_scope=nil)
      initial_scope ||= @scope
      task_name = task_name.to_s
      if task_name =~ /^rake:/
        scopes = Scope.make
        task_name = task_name.sub(/^rake:/, '')
      elsif task_name =~ /^(\^+)/
        scopes = initial_scope.trim($1.size)
        task_name = task_name.sub(/^(\^+)/, '')
      else
        scopes = initial_scope
      end
      lookup_in_scope(task_name, scopes)
    end

    def lookup_in_scope(name, scope)
      loop do
        tn = scope.path_with_task_name(name)
        task = @tasks[tn]
        return task if task
        break if scope.empty?
        scope = scope.tail
      end
      nil
    end
    private :lookup_in_scope

    def current_scope
      @scope
    end

    def in_namespace(name)
      name ||= generate_name
      @scope = Scope.new(name, @scope)
      ns = NameSpace.new(self, @scope)
      yield(ns)
      ns
    ensure
      @scope = @scope.tail
    end

    private

    def add_location(task)
      loc = find_location
      task.locations << loc if loc
      task
    end

    def find_location
      locations = caller
      i = 0
      while locations[i]
        return locations[i + 1] if locations[i] =~ /rake\/dsl_definition.rb/
        i += 1
      end
      nil
    end

    def generate_name
      @seed ||= 0
      @seed += 1
      "_anon_#{@seed}"
    end

    def trace_rule(level, message) # :nodoc:
      options.trace_output.puts "#{"    " * level}#{message}" if
        Rake.application.options.trace_rules
    end

    def attempt_rule(task_name, args, extensions, block, level)
      sources = make_sources(task_name, extensions)
      prereqs = sources.map { |source|
        trace_rule level, "Attempting Rule #{task_name} => #{source}"
        if File.exist?(source) || Rake::Task.task_defined?(source)
          trace_rule level, "(#{task_name} => #{source} ... EXIST)"
          source
        elsif parent = enhance_with_matching_rule(source, level + 1)
          trace_rule level, "(#{task_name} => #{source} ... ENHANCE)"
          parent.name
        else
          trace_rule level, "(#{task_name} => #{source} ... FAIL)"
          return nil
        end
      }
      task = FileTask.define_task(task_name, {args => prereqs}, &block)
      task.sources = prereqs
      task
    end

    def make_sources(task_name, extensions)
      result = extensions.map { |ext|
        case ext
        when /%/
          task_name.pathmap(ext)
        when %r{/}
          ext
        when /^\./
          task_name.ext(ext)
        when String
          ext
        when Proc, Method
          if ext.arity == 1
            ext.call(task_name)
          else
            ext.call
          end
        else
          fail "Don't know how to handle rule dependent: #{ext.inspect}"
        end
      }
      result.flatten
    end


    private

    def get_description(task)
      desc = @last_description
      @last_description = nil
      desc
    end

    class << self
      attr_accessor :record_task_metadata # :nodoc:
      TaskManager.record_task_metadata = false
    end
  end

end
