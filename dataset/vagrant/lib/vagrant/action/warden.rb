require "log4r"

module Vagrant
  module Action
    class Warden
      attr_accessor :actions, :stack

      def initialize(actions, env)
        @stack      = []
        @actions    = actions.map { |m| finalize_action(m, env) }
        @logger     = Log4r::Logger.new("vagrant::action::warden")
        @last_error = nil
      end

      def call(env)
        return if @actions.empty?

        begin
          raise Errors::VagrantInterrupt if env[:interrupted]
          action = @actions.shift
          @logger.info("Calling IN action: #{action}")
          @stack.unshift(action).first.call(env)
          raise Errors::VagrantInterrupt if env[:interrupted]
          @logger.info("Calling OUT action: #{action}")
        rescue SystemExit
          raise
        rescue Exception => e
          if e != @last_error
            @logger.error("Error occurred: #{e}")
            @last_error = e
          end

          env["vagrant.error"] = e

          recover(env)
          raise
        end
      end

      def recover(env)
        @logger.info("Beginning recovery process...")

        @stack.each do |act|
          if act.respond_to?(:recover)
            @logger.info("Calling recover: #{act}")
            act.recover(env)
          end
        end

        @logger.info("Recovery complete.")

        @stack.clear
      end

      def finalize_action(action, env)
        klass, args, block = action

        args ||= []

        if klass.is_a?(Class)
          klass.new(self, env, *args, &block)
        elsif klass.respond_to?(:call)
          lambda do |e|
            klass.call(e)
            self.call(e)
          end
        else
          raise "Invalid action: #{action.inspect}"
        end
      end
    end
  end
end
