require 'active_support/concern'
require 'active_support/descendants_tracker'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/kernel/reporting'
require 'active_support/core_ext/kernel/singleton_class'
require 'thread'

module ActiveSupport
  module Callbacks
    extend Concern

    included do
      extend ActiveSupport::DescendantsTracker
    end

    CALLBACK_FILTER_TYPES = [:before, :after, :around]

    def run_callbacks(kind, &block)
      #nodyna <send-984> <SD MODERATE (change-prone variables)>
      send "_run_#{kind}_callbacks", &block
    end

    private

    def __run_callbacks__(callbacks, &block)
      if callbacks.empty?
        yield if block_given?
      else
        runner = callbacks.compile
        e = Filters::Environment.new(self, false, nil, block)
        runner.call(e).value
      end
    end

    def halted_callback_hook(filter)
    end

    module Conditionals # :nodoc:
      class Value
        def initialize(&block)
          @block = block
        end
        def call(target, value); @block.call(value); end
      end
    end

    module Filters
      Environment = Struct.new(:target, :halted, :value, :run_block)

      class End
        def call(env)
          block = env.run_block
          env.value = !env.halted && (!block || block.call)
          env
        end
      end
      ENDING = End.new

      class Before
        def self.build(callback_sequence, user_callback, user_conditions, chain_config, filter)
          halted_lambda = chain_config[:terminator]

          if chain_config.key?(:terminator) && user_conditions.any?
            halting_and_conditional(callback_sequence, user_callback, user_conditions, halted_lambda, filter)
          elsif chain_config.key? :terminator
            halting(callback_sequence, user_callback, halted_lambda, filter)
          elsif user_conditions.any?
            conditional(callback_sequence, user_callback, user_conditions)
          else
            simple callback_sequence, user_callback
          end
        end

        def self.halting_and_conditional(callback_sequence, user_callback, user_conditions, halted_lambda, filter)
          callback_sequence.before do |env|
            target = env.target
            value  = env.value
            halted = env.halted

            if !halted && user_conditions.all? { |c| c.call(target, value) }
              result = user_callback.call target, value
              env.halted = halted_lambda.call(target, result)
              if env.halted
                #nodyna <send-985> <SD EASY (private methods)>
                target.send :halted_callback_hook, filter
              end
            end

            env
          end
        end
        private_class_method :halting_and_conditional

        def self.halting(callback_sequence, user_callback, halted_lambda, filter)
          callback_sequence.before do |env|
            target = env.target
            value  = env.value
            halted = env.halted

            unless halted
              result = user_callback.call target, value
              env.halted = halted_lambda.call(target, result)
              if env.halted
                #nodyna <send-986> <SD EASY (private methods)>
                target.send :halted_callback_hook, filter
              end
            end

            env
          end
        end
        private_class_method :halting

        def self.conditional(callback_sequence, user_callback, user_conditions)
          callback_sequence.before do |env|
            target = env.target
            value  = env.value

            if user_conditions.all? { |c| c.call(target, value) }
              user_callback.call target, value
            end

            env
          end
        end
        private_class_method :conditional

        def self.simple(callback_sequence, user_callback)
          callback_sequence.before do |env|
            user_callback.call env.target, env.value

            env
          end
        end
        private_class_method :simple
      end

      class After
        def self.build(callback_sequence, user_callback, user_conditions, chain_config)
          if chain_config[:skip_after_callbacks_if_terminated]
            if chain_config.key?(:terminator) && user_conditions.any?
              halting_and_conditional(callback_sequence, user_callback, user_conditions)
            elsif chain_config.key?(:terminator)
              halting(callback_sequence, user_callback)
            elsif user_conditions.any?
              conditional callback_sequence, user_callback, user_conditions
            else
              simple callback_sequence, user_callback
            end
          else
            if user_conditions.any?
              conditional callback_sequence, user_callback, user_conditions
            else
              simple callback_sequence, user_callback
            end
          end
        end

        def self.halting_and_conditional(callback_sequence, user_callback, user_conditions)
          callback_sequence.after do |env|
            target = env.target
            value  = env.value
            halted = env.halted

            if !halted && user_conditions.all? { |c| c.call(target, value) }
              user_callback.call target, value
            end

            env
          end
        end
        private_class_method :halting_and_conditional

        def self.halting(callback_sequence, user_callback)
          callback_sequence.after do |env|
            unless env.halted
              user_callback.call env.target, env.value
            end

            env
          end
        end
        private_class_method :halting

        def self.conditional(callback_sequence, user_callback, user_conditions)
          callback_sequence.after do |env|
            target = env.target
            value  = env.value

            if user_conditions.all? { |c| c.call(target, value) }
              user_callback.call target, value
            end

            env
          end
        end
        private_class_method :conditional

        def self.simple(callback_sequence, user_callback)
          callback_sequence.after do |env|
            user_callback.call env.target, env.value

            env
          end
        end
        private_class_method :simple
      end

      class Around
        def self.build(callback_sequence, user_callback, user_conditions, chain_config)
          if chain_config.key?(:terminator) && user_conditions.any?
            halting_and_conditional(callback_sequence, user_callback, user_conditions)
          elsif chain_config.key? :terminator
            halting(callback_sequence, user_callback)
          elsif user_conditions.any?
            conditional(callback_sequence, user_callback, user_conditions)
          else
            simple(callback_sequence, user_callback)
          end
        end

        def self.halting_and_conditional(callback_sequence, user_callback, user_conditions)
          callback_sequence.around do |env, &run|
            target = env.target
            value  = env.value
            halted = env.halted

            if !halted && user_conditions.all? { |c| c.call(target, value) }
              user_callback.call(target, value) {
                env = run.call env
                env.value
              }

              env
            else
              run.call env
            end
          end
        end
        private_class_method :halting_and_conditional

        def self.halting(callback_sequence, user_callback)
          callback_sequence.around do |env, &run|
            target = env.target
            value  = env.value

            if env.halted
              run.call env
            else
              user_callback.call(target, value) {
                env = run.call env
                env.value
              }
              env
            end
          end
        end
        private_class_method :halting

        def self.conditional(callback_sequence, user_callback, user_conditions)
          callback_sequence.around do |env, &run|
            target = env.target
            value  = env.value

            if user_conditions.all? { |c| c.call(target, value) }
              user_callback.call(target, value) {
                env = run.call env
                env.value
              }
              env
            else
              run.call env
            end
          end
        end
        private_class_method :conditional

        def self.simple(callback_sequence, user_callback)
          callback_sequence.around do |env, &run|
            user_callback.call(env.target, env.value) {
              env = run.call env
              env.value
            }
            env
          end
        end
        private_class_method :simple
      end
    end

    class Callback #:nodoc:#
      def self.build(chain, filter, kind, options)
        new chain.name, filter, kind, options, chain.config
      end

      attr_accessor :kind, :name
      attr_reader :chain_config

      def initialize(name, filter, kind, options, chain_config)
        @chain_config  = chain_config
        @name    = name
        @kind    = kind
        @filter  = filter
        @key     = compute_identifier filter
        @if      = Array(options[:if])
        @unless  = Array(options[:unless])
      end

      def filter; @key; end
      def raw_filter; @filter; end

      def merge(chain, new_options)
        options = {
          :if     => @if.dup,
          :unless => @unless.dup
        }

        options[:if].concat     Array(new_options.fetch(:unless, []))
        options[:unless].concat Array(new_options.fetch(:if, []))

        self.class.build chain, @filter, @kind, options
      end

      def matches?(_kind, _filter)
        @kind == _kind && filter == _filter
      end

      def duplicates?(other)
        case @filter
        when Symbol, String
          matches?(other.kind, other.filter)
        else
          false
        end
      end

      def apply(callback_sequence)
        user_conditions = conditions_lambdas
        user_callback = make_lambda @filter

        case kind
        when :before
          Filters::Before.build(callback_sequence, user_callback, user_conditions, chain_config, @filter)
        when :after
          Filters::After.build(callback_sequence, user_callback, user_conditions, chain_config)
        when :around
          Filters::Around.build(callback_sequence, user_callback, user_conditions, chain_config)
        end
      end

      private

      def invert_lambda(l)
        lambda { |*args, &blk| !l.call(*args, &blk) }
      end

      def make_lambda(filter)
        case filter
        when Symbol
          #nodyna <send-987> <SD COMPLEX (change-prone variables)>
          lambda { |target, _, &blk| target.send filter, &blk }
        when String
          #nodyna <eval-988> <EV COMPLEX (change-prone variables)>
          l = eval "lambda { |value| #{filter} }"
          #nodyna <instance_exec-989> <IEX COMPLEX (block with parameters)>
          lambda { |target, value| target.instance_exec(value, &l) }
        when Conditionals::Value then filter
        when ::Proc
          if filter.arity > 1
            return lambda { |target, _, &block|
              raise ArgumentError unless block
              #nodyna <instance_exec-990> <IEX COMPLEX (block with parameters)>
              target.instance_exec(target, block, &filter)
            }
          end

          if filter.arity <= 0
            #nodyna <instance_exec-991> <IEX COMPLEX (block without parameters)>
            lambda { |target, _| target.instance_exec(&filter) }
          else
            #nodyna <instance_exec-992> <IEX COMPLEX (block with parameters)>
            lambda { |target, _| target.instance_exec(target, &filter) }
          end
        else
          scopes = Array(chain_config[:scope])
          #nodyna <send-993> <SD COMPLEX (change-prone variables)>
          method_to_call = scopes.map{ |s| public_send(s) }.join("_")

          lambda { |target, _, &blk|
            #nodyna <send-994> <SD COMPLEX (change-prone variables)>
            filter.public_send method_to_call, target, &blk
          }
        end
      end

      def compute_identifier(filter)
        case filter
        when String, ::Proc
          filter.object_id
        else
          filter
        end
      end

      def conditions_lambdas
        @if.map { |c| make_lambda c } +
          @unless.map { |c| invert_lambda make_lambda c }
      end
    end

    class CallbackSequence
      def initialize(&call)
        @call = call
        @before = []
        @after = []
      end

      def before(&before)
        @before.unshift(before)
        self
      end

      def after(&after)
        @after.push(after)
        self
      end

      def around(&around)
        CallbackSequence.new do |*args|
          around.call(*args) {
            self.call(*args)
          }
        end
      end

      def call(*args)
        @before.each { |b| b.call(*args) }
        value = @call.call(*args)
        @after.each { |a| a.call(*args) }
        value
      end
    end

    class CallbackChain #:nodoc:#
      include Enumerable

      attr_reader :name, :config

      def initialize(name, config)
        @name = name
        @config = {
          :scope => [ :kind ]
        }.merge!(config)
        @chain = []
        @callbacks = nil
        @mutex = Mutex.new
      end

      def each(&block); @chain.each(&block); end
      def index(o);     @chain.index(o); end
      def empty?;       @chain.empty?; end

      def insert(index, o)
        @callbacks = nil
        @chain.insert(index, o)
      end

      def delete(o)
        @callbacks = nil
        @chain.delete(o)
      end

      def clear
        @callbacks = nil
        @chain.clear
        self
      end

      def initialize_copy(other)
        @callbacks = nil
        @chain     = other.chain.dup
        @mutex     = Mutex.new
      end

      def compile
        @callbacks || @mutex.synchronize do
          final_sequence = CallbackSequence.new { |env| Filters::ENDING.call(env) }
          @callbacks ||= @chain.reverse.inject(final_sequence) do |callback_sequence, callback|
            callback.apply callback_sequence
          end
        end
      end

      def append(*callbacks)
        callbacks.each { |c| append_one(c) }
      end

      def prepend(*callbacks)
        callbacks.each { |c| prepend_one(c) }
      end

      protected
      def chain; @chain; end

      private

      def append_one(callback)
        @callbacks = nil
        remove_duplicates(callback)
        @chain.push(callback)
      end

      def prepend_one(callback)
        @callbacks = nil
        remove_duplicates(callback)
        @chain.unshift(callback)
      end

      def remove_duplicates(callback)
        @callbacks = nil
        @chain.delete_if { |c| callback.duplicates?(c) }
      end
    end

    module ClassMethods
      def normalize_callback_params(filters, block) # :nodoc:
        type = CALLBACK_FILTER_TYPES.include?(filters.first) ? filters.shift : :before
        options = filters.extract_options!
        filters.unshift(block) if block
        [type, filters, options.dup]
      end

      def __update_callbacks(name) #:nodoc:
        ([self] + ActiveSupport::DescendantsTracker.descendants(self)).reverse_each do |target|
          chain = target.get_callbacks name
          yield target, chain.dup
        end
      end

      def set_callback(name, *filter_list, &block)
        type, filters, options = normalize_callback_params(filter_list, block)
        self_chain = get_callbacks name
        mapped = filters.map do |filter|
          Callback.build(self_chain, filter, type, options)
        end

        __update_callbacks(name) do |target, chain|
          options[:prepend] ? chain.prepend(*mapped) : chain.append(*mapped)
          target.set_callbacks name, chain
        end
      end

      def skip_callback(name, *filter_list, &block)
        type, filters, options = normalize_callback_params(filter_list, block)

        __update_callbacks(name) do |target, chain|
          filters.each do |filter|
            filter = chain.find {|c| c.matches?(type, filter) }

            if filter && options.any?
              new_filter = filter.merge(chain, options)
              chain.insert(chain.index(filter), new_filter)
            end

            chain.delete(filter)
          end
          target.set_callbacks name, chain
        end
      end

      def reset_callbacks(name)
        callbacks = get_callbacks name

        ActiveSupport::DescendantsTracker.descendants(self).each do |target|
          chain = target.get_callbacks(name).dup
          callbacks.each { |c| chain.delete(c) }
          target.set_callbacks name, chain
        end

        self.set_callbacks name, callbacks.dup.clear
      end

      def define_callbacks(*names)
        options = names.extract_options!

        names.each do |name|
          class_attribute "_#{name}_callbacks"
          set_callbacks name, CallbackChain.new(name, options)

          #nodyna <module_eval-995> <ME MODERATE (define methods)>
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def _run_#{name}_callbacks(&block)
              __run_callbacks__(_#{name}_callbacks, &block)
            end
          RUBY
        end
      end

      protected

      def get_callbacks(name)
        #nodyna <send-996> <SD MODERATE (change-prone variables)>
        send "_#{name}_callbacks"
      end

      def set_callbacks(name, callbacks)
        #nodyna <send-997> <SD MODERATE (change-prone variables)>
        send "_#{name}_callbacks=", callbacks
      end
    end
  end
end
