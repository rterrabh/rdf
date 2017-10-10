require 'rails/initializable'
require 'rails/configuration'
require 'active_support/inflector'
require 'active_support/core_ext/module/introspection'
require 'active_support/core_ext/module/delegation'

module Rails
  class Railtie
    autoload :Configuration, "rails/railtie/configuration"

    include Initializable

    ABSTRACT_RAILTIES = %w(Rails::Railtie Rails::Engine Rails::Application)

    class << self
      private :new
      delegate :config, to: :instance

      def subclasses
        @subclasses ||= []
      end

      def inherited(base)
        unless base.abstract_railtie?
          subclasses << base
        end
      end

      def rake_tasks(&blk)
        @rake_tasks ||= []
        @rake_tasks << blk if blk
        @rake_tasks
      end

      def console(&blk)
        @load_console ||= []
        @load_console << blk if blk
        @load_console
      end

      def runner(&blk)
        @load_runner ||= []
        @load_runner << blk if blk
        @load_runner
      end

      def generators(&blk)
        @generators ||= []
        @generators << blk if blk
        @generators
      end

      def abstract_railtie?
        ABSTRACT_RAILTIES.include?(name)
      end

      def railtie_name(name = nil)
        @railtie_name = name.to_s if name
        @railtie_name ||= generate_railtie_name(self.name)
      end

      def instance
        @instance ||= new
      end

      def respond_to_missing?(*args)
        instance.respond_to?(*args) || super
      end

      def configure(&block)
        instance.configure(&block)
      end

      protected
        def generate_railtie_name(string)
          ActiveSupport::Inflector.underscore(string).tr("/", "_")
        end

        def method_missing(name, *args, &block)
          if instance.respond_to?(name)
            #nodyna <send-1144> <SD COMPLEX (change-prone variables)>
            instance.public_send(name, *args, &block)
          else
            super
          end
        end
    end

    delegate :railtie_name, to: :class

    def initialize
      if self.class.abstract_railtie?
        raise "#{self.class.name} is abstract, you cannot instantiate it directly."
      end
    end

    def configure(&block)
      #nodyna <instance_eval-1145> <IEV COMPLEX (block execution)>
      instance_eval(&block)
    end

    def config
      @config ||= Railtie::Configuration.new
    end

    def railtie_namespace
      @railtie_namespace ||= self.class.parents.detect { |n| n.respond_to?(:railtie_namespace) }
    end

    protected

    def run_console_blocks(app) #:nodoc:
      each_registered_block(:console) { |block| block.call(app) }
    end

    def run_generators_blocks(app) #:nodoc:
      each_registered_block(:generators) { |block| block.call(app) }
    end

    def run_runner_blocks(app) #:nodoc:
      each_registered_block(:runner) { |block| block.call(app) }
    end

    def run_tasks_blocks(app) #:nodoc:
      extend Rake::DSL
      #nodyna <instance_exec-1146> <IEX COMPLEX (block with parameters)>
      each_registered_block(:rake_tasks) { |block| instance_exec(app, &block) }
    end

    private

    def each_registered_block(type, &block)
      klass = self.class
      while klass.respond_to?(type)
        #nodyna <send-1147> <SD MODERATE (change-prone variables)>
        klass.public_send(type).each(&block)
        klass = klass.superclass
      end
    end
  end
end
