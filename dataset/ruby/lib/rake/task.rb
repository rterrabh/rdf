require 'rake/invocation_exception_mixin'

module Rake

  class Task
    attr_reader :prerequisites

    attr_reader :actions

    attr_accessor :application

    attr_reader :scope

    attr_reader :locations

    def to_s
      name
    end

    def inspect # :nodoc:
      "<#{self.class} #{name} => [#{prerequisites.join(', ')}]>"
    end

    attr_writer :sources
    def sources
      if defined?(@sources)
        @sources
      else
        prerequisites
      end
    end

    def prerequisite_tasks
      prerequisites.map { |pre| lookup_prerequisite(pre) }
    end

    def lookup_prerequisite(prerequisite_name) # :nodoc:
      application[prerequisite_name, @scope]
    end
    private :lookup_prerequisite

    def all_prerequisite_tasks
      seen = {}
      collect_prerequisites(seen)
      seen.values
    end

    def collect_prerequisites(seen) # :nodoc:
      prerequisite_tasks.each do |pre|
        next if seen[pre.name]
        seen[pre.name] = pre
        pre.collect_prerequisites(seen)
      end
    end
    protected :collect_prerequisites

    def source
      sources.first
    end

    def initialize(task_name, app)
      @name            = task_name.to_s
      @prerequisites   = []
      @actions         = []
      @already_invoked = false
      @comments        = []
      @lock            = Monitor.new
      @application     = app
      @scope           = app.current_scope
      @arg_names       = nil
      @locations       = []
    end

    def enhance(deps=nil, &block)
      @prerequisites |= deps if deps
      @actions << block if block_given?
      self
    end

    def name
      @name.to_s
    end

    def name_with_args # :nodoc:
      if arg_description
        "#{name}#{arg_description}"
      else
        name
      end
    end

    def arg_description # :nodoc:
      @arg_names ? "[#{arg_names.join(',')}]" : nil
    end

    def arg_names
      @arg_names || []
    end

    def reenable
      @already_invoked = false
    end

    def clear
      clear_prerequisites
      clear_actions
      clear_comments
      self
    end

    def clear_prerequisites
      prerequisites.clear
      self
    end

    def clear_actions
      actions.clear
      self
    end

    def clear_comments
      @comments = []
      self
    end

    def invoke(*args)
      task_args = TaskArguments.new(arg_names, args)
      invoke_with_call_chain(task_args, InvocationChain::EMPTY)
    end

    def invoke_with_call_chain(task_args, invocation_chain) # :nodoc:
      new_chain = InvocationChain.append(self, invocation_chain)
      @lock.synchronize do
        if application.options.trace
          application.trace "** Invoke #{name} #{format_trace_flags}"
        end
        return if @already_invoked
        @already_invoked = true
        invoke_prerequisites(task_args, new_chain)
        execute(task_args) if needed?
      end
    rescue Exception => ex
      add_chain_to(ex, new_chain)
      raise ex
    end
    protected :invoke_with_call_chain

    def add_chain_to(exception, new_chain) # :nodoc:
      exception.extend(InvocationExceptionMixin) unless
        exception.respond_to?(:chain)
      exception.chain = new_chain if exception.chain.nil?
    end
    private :add_chain_to

    def invoke_prerequisites(task_args, invocation_chain) # :nodoc:
      if application.options.always_multitask
        invoke_prerequisites_concurrently(task_args, invocation_chain)
      else
        prerequisite_tasks.each { |p|
          prereq_args = task_args.new_scope(p.arg_names)
          p.invoke_with_call_chain(prereq_args, invocation_chain)
        }
      end
    end

    def invoke_prerequisites_concurrently(task_args, invocation_chain)# :nodoc:
      futures = prerequisite_tasks.map do |p|
        prereq_args = task_args.new_scope(p.arg_names)
        application.thread_pool.future(p) do |r|
          r.invoke_with_call_chain(prereq_args, invocation_chain)
        end
      end
      futures.each { |f| f.value }
    end

    def format_trace_flags
      flags = []
      flags << "first_time" unless @already_invoked
      flags << "not_needed" unless needed?
      flags.empty? ? "" : "(" + flags.join(", ") + ")"
    end
    private :format_trace_flags

    def execute(args=nil)
      args ||= EMPTY_TASK_ARGS
      if application.options.dryrun
        application.trace "** Execute (dry run) #{name}"
        return
      end
      application.trace "** Execute #{name}" if application.options.trace
      application.enhance_with_matching_rule(name) if @actions.empty?
      @actions.each do |act|
        case act.arity
        when 1
          act.call(self)
        else
          act.call(self, args)
        end
      end
    end

    def needed?
      true
    end

    def timestamp
      Time.now
    end

    def add_description(description)
      return unless description
      comment = description.strip
      add_comment(comment) if comment && ! comment.empty?
    end

    def comment=(comment) # :nodoc:
      add_comment(comment)
    end

    def add_comment(comment) # :nodoc:
      return if comment.nil?
      @comments << comment unless @comments.include?(comment)
    end
    private :add_comment

    def full_comment
      transform_comments("\n")
    end

    def comment
      transform_comments(" / ") { |c| first_sentence(c) }
    end

    def transform_comments(separator, &block)
      if @comments.empty?
        nil
      else
        block ||= lambda { |c| c }
        @comments.map(&block).join(separator)
      end
    end
    private :transform_comments

    def first_sentence(string)
      string.split(/\.[ \t]|\.$|\n/).first
    end
    private :first_sentence

    def set_arg_names(args)
      @arg_names = args.map { |a| a.to_sym }
    end

    def investigation
      result = "------------------------------\n"
      result << "Investigating #{name}\n"
      result << "class: #{self.class}\n"
      result <<  "task needed: #{needed?}\n"
      result <<  "timestamp: #{timestamp}\n"
      result << "pre-requisites: \n"
      prereqs = prerequisite_tasks
      prereqs.sort! { |a, b| a.timestamp <=> b.timestamp }
      prereqs.each do |p|
        result << "--#{p.name} (#{p.timestamp})\n"
      end
      latest_prereq = prerequisite_tasks.map { |pre| pre.timestamp }.max
      result <<  "latest-prerequisite time: #{latest_prereq}\n"
      result << "................................\n\n"
      return result
    end

    class << self

      def clear
        Rake.application.clear
      end

      def tasks
        Rake.application.tasks
      end

      def [](task_name)
        Rake.application[task_name]
      end

      def task_defined?(task_name)
        Rake.application.lookup(task_name) != nil
      end

      def define_task(*args, &block)
        Rake.application.define_task(self, *args, &block)
      end

      def create_rule(*args, &block)
        Rake.application.create_rule(*args, &block)
      end

      def scope_name(scope, task_name)
        scope.path_with_task_name(task_name)
      end

    end # class << Rake::Task
  end # class Rake::Task
end
