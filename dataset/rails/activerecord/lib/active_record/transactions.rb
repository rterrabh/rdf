module ActiveRecord
  module Transactions
    extend ActiveSupport::Concern
    ACTIONS = [:create, :destroy, :update]
    CALLBACK_WARN_MESSAGE = "Currently, Active Record suppresses errors raised " \
      "within `after_rollback`/`after_commit` callbacks and only print them to " \
      "the logs. In the next version, these errors will no longer be suppressed. " \
      "Instead, the errors will propagate normally just like in other Active " \
      "Record callbacks.\n" \
      "\n" \
      "You can opt into the new behavior and remove this warning by setting:\n" \
      "\n" \
      "  config.active_record.raise_in_transactional_callbacks = true\n\n"

    included do
      define_callbacks :commit, :rollback,
                       terminator: ->(_, result) { result == false },
                       scope: [:kind, :name]

      mattr_accessor :raise_in_transactional_callbacks, instance_writer: false
      self.raise_in_transactional_callbacks = false
    end

    module ClassMethods
      def transaction(options = {}, &block)
        connection.transaction(options, &block)
      end

      def after_commit(*args, &block)
        set_options_for_callbacks!(args)
        set_callback(:commit, :after, *args, &block)
        unless ActiveRecord::Base.raise_in_transactional_callbacks
          ActiveSupport::Deprecation.warn(CALLBACK_WARN_MESSAGE)
        end
      end

      def after_rollback(*args, &block)
        set_options_for_callbacks!(args)
        set_callback(:rollback, :after, *args, &block)
        unless ActiveRecord::Base.raise_in_transactional_callbacks
          ActiveSupport::Deprecation.warn(CALLBACK_WARN_MESSAGE)
        end
      end

      private

      def set_options_for_callbacks!(args)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          fire_on = Array(options[:on])
          assert_valid_transaction_action(fire_on)
          options[:if] = Array(options[:if])
          options[:if] << "transaction_include_any_action?(#{fire_on})"
        end
      end

      def assert_valid_transaction_action(actions)
        if (actions - ACTIONS).any?
          raise ArgumentError, ":on conditions for after_commit and after_rollback callbacks have to be one of #{ACTIONS}"
        end
      end
    end

    def transaction(options = {}, &block)
      self.class.transaction(options, &block)
    end

    def destroy #:nodoc:
      with_transaction_returning_status { super }
    end

    def save(*) #:nodoc:
      rollback_active_record_state! do
        with_transaction_returning_status { super }
      end
    end

    def save!(*) #:nodoc:
      with_transaction_returning_status { super }
    end

    def touch(*) #:nodoc:
      with_transaction_returning_status { super }
    end

    def rollback_active_record_state!
      remember_transaction_record_state
      yield
    rescue Exception
      restore_transaction_record_state
      raise
    ensure
      clear_transaction_record_state
    end

    def committed!(should_run_callbacks = true) #:nodoc:
      _run_commit_callbacks if should_run_callbacks && destroyed? || persisted?
    ensure
      force_clear_transaction_record_state
    end

    def rolledback!(force_restore_state = false, should_run_callbacks = true) #:nodoc:
      _run_rollback_callbacks if should_run_callbacks
    ensure
      restore_transaction_record_state(force_restore_state)
      clear_transaction_record_state
    end

    def add_to_transaction
      if has_transactional_callbacks?
        self.class.connection.add_transaction_record(self)
      else
        sync_with_transaction_state
        set_transaction_state(self.class.connection.transaction_state)
      end
      remember_transaction_record_state
    end

    def with_transaction_returning_status
      status = nil
      self.class.transaction do
        add_to_transaction
        begin
          status = yield
        rescue ActiveRecord::Rollback
          clear_transaction_record_state
          status = nil
        end

        raise ActiveRecord::Rollback unless status
      end
      status
    ensure
      if @transaction_state && @transaction_state.committed?
        clear_transaction_record_state
      end
    end

    protected

    def remember_transaction_record_state #:nodoc:
      @_start_transaction_state[:id] = id
      @_start_transaction_state.reverse_merge!(
        new_record: @new_record,
        destroyed: @destroyed,
        frozen?: frozen?,
      )
      @_start_transaction_state[:level] = (@_start_transaction_state[:level] || 0) + 1
    end

    def clear_transaction_record_state #:nodoc:
      @_start_transaction_state[:level] = (@_start_transaction_state[:level] || 0) - 1
      force_clear_transaction_record_state if @_start_transaction_state[:level] < 1
    end

    def force_clear_transaction_record_state #:nodoc:
      @_start_transaction_state.clear
    end

    def restore_transaction_record_state(force = false) #:nodoc:
      unless @_start_transaction_state.empty?
        transaction_level = (@_start_transaction_state[:level] || 0) - 1
        if transaction_level < 1 || force
          restore_state = @_start_transaction_state
          thaw
          @new_record = restore_state[:new_record]
          @destroyed  = restore_state[:destroyed]
          pk = self.class.primary_key
          if pk && read_attribute(pk) != restore_state[:id]
            write_attribute(pk, restore_state[:id])
          end
          freeze if restore_state[:frozen?]
        end
      end
    end

    def transaction_record_state(state) #:nodoc:
      @_start_transaction_state[state]
    end

    def transaction_include_any_action?(actions) #:nodoc:
      actions.any? do |action|
        case action
        when :create
          transaction_record_state(:new_record)
        when :destroy
          destroyed?
        when :update
          !(transaction_record_state(:new_record) || destroyed?)
        end
      end
    end
  end
end
