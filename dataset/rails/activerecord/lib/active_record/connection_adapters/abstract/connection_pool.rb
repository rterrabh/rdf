require 'thread'
require 'thread_safe'
require 'monitor'
require 'set'
require 'active_support/core_ext/string/filters'

module ActiveRecord
  class ConnectionTimeoutError < ConnectionNotEstablished
  end

  module ConnectionAdapters
    class ConnectionPool
      class Queue
        def initialize(lock = Monitor.new)
          @lock = lock
          @cond = @lock.new_cond
          @num_waiting = 0
          @queue = []
        end

        def any_waiting?
          synchronize do
            @num_waiting > 0
          end
        end

        def num_waiting
          synchronize do
            @num_waiting
          end
        end

        def add(element)
          synchronize do
            @queue.push element
            @cond.signal
          end
        end

        def delete(element)
          synchronize do
            @queue.delete(element)
          end
        end

        def clear
          synchronize do
            @queue.clear
          end
        end

        def poll(timeout = nil)
          synchronize do
            if timeout
              no_wait_poll || wait_poll(timeout)
            else
              no_wait_poll
            end
          end
        end

        private

        def synchronize(&block)
          @lock.synchronize(&block)
        end

        def any?
          !@queue.empty?
        end

        def can_remove_no_wait?
          @queue.size > @num_waiting
        end

        def remove
          @queue.shift
        end

        def no_wait_poll
          remove if can_remove_no_wait?
        end

        def wait_poll(timeout)
          @num_waiting += 1

          t0 = Time.now
          elapsed = 0
          loop do
            @cond.wait(timeout - elapsed)

            return remove if any?

            elapsed = Time.now - t0
            if elapsed >= timeout
              msg = 'could not obtain a database connection within %0.3f seconds (waited %0.3f seconds)' %
                [timeout, elapsed]
              raise ConnectionTimeoutError, msg
            end
          end
        ensure
          @num_waiting -= 1
        end
      end

      class Reaper
        attr_reader :pool, :frequency

        def initialize(pool, frequency)
          @pool      = pool
          @frequency = frequency
        end

        def run
          return unless frequency
          Thread.new(frequency, pool) { |t, p|
            while true
              sleep t
              p.reap
            end
          }
        end
      end

      include MonitorMixin

      attr_accessor :automatic_reconnect, :checkout_timeout
      attr_reader :spec, :connections, :size, :reaper

      def initialize(spec)
        super()

        @spec = spec

        @checkout_timeout = (spec.config[:checkout_timeout] && spec.config[:checkout_timeout].to_f) || 5
        @reaper = Reaper.new(self, (spec.config[:reaping_frequency] && spec.config[:reaping_frequency].to_f))
        @reaper.run

        @size = (spec.config[:pool] && spec.config[:pool].to_i) || 5

        @reserved_connections = ThreadSafe::Cache.new(:initial_capacity => @size)

        @connections         = []
        @automatic_reconnect = true

        @available = Queue.new self
      end

      def connection
        @reserved_connections[current_connection_id] || synchronize do
          @reserved_connections[current_connection_id] ||= checkout
        end
      end

      def active_connection?
        synchronize do
          @reserved_connections.fetch(current_connection_id) {
            return false
          }.in_use?
        end
      end

      def release_connection(with_id = current_connection_id)
        synchronize do
          conn = @reserved_connections.delete(with_id)
          checkin conn if conn
        end
      end

      def with_connection
        connection_id = current_connection_id
        fresh_connection = true unless active_connection?
        yield connection
      ensure
        release_connection(connection_id) if fresh_connection
      end

      def connected?
        synchronize { @connections.any? }
      end

      def disconnect!
        synchronize do
          @reserved_connections.clear
          @connections.each do |conn|
            checkin conn
            conn.disconnect!
          end
          @connections = []
          @available.clear
        end
      end

      def clear_reloadable_connections!
        synchronize do
          @reserved_connections.clear
          @connections.each do |conn|
            checkin conn
            conn.disconnect! if conn.requires_reloading?
          end
          @connections.delete_if do |conn|
            conn.requires_reloading?
          end
          @available.clear
          @connections.each do |conn|
            @available.add conn
          end
        end
      end

      def checkout
        synchronize do
          conn = acquire_connection
          conn.lease
          checkout_and_verify(conn)
        end
      end

      def checkin(conn)
        synchronize do
          owner = conn.owner

          conn._run_checkin_callbacks do
            conn.expire
          end

          release conn, owner

          @available.add conn
        end
      end

      def remove(conn)
        synchronize do
          @connections.delete conn
          @available.delete conn

          release conn, conn.owner

          @available.add checkout_new_connection if @available.any_waiting?
        end
      end

      def reap
        stale_connections = synchronize do
          @connections.select do |conn|
            conn.in_use? && !conn.owner.alive?
          end
        end

        stale_connections.each do |conn|
          synchronize do
            if conn.active?
              conn.reset!
              checkin conn
            else
              remove conn
            end
          end
        end
      end

      private

      def acquire_connection
        if conn = @available.poll
          conn
        elsif @connections.size < @size
          checkout_new_connection
        else
          reap
          @available.poll(@checkout_timeout)
        end
      end

      def release(conn, owner)
        thread_id = owner.object_id

        if @reserved_connections[thread_id] == conn
          @reserved_connections.delete thread_id
        end
      end

      def new_connection
        #nodyna <send-916> <SD COMPLEX (change-prone variables)>
        Base.send(spec.adapter_method, spec.config)
      end

      def current_connection_id #:nodoc:
        Base.connection_id ||= Thread.current.object_id
      end

      def checkout_new_connection
        raise ConnectionNotEstablished unless @automatic_reconnect

        c = new_connection
        c.pool = self
        @connections << c
        c
      end

      def checkout_and_verify(c)
        c._run_checkout_callbacks do
          c.verify!
        end
        c
      rescue
        remove c
        c.disconnect!
        raise
      end
    end

    class ConnectionHandler
      def initialize
        @owner_to_pool = ThreadSafe::Cache.new(:initial_capacity => 2) do |h,k|
          h[k] = ThreadSafe::Cache.new(:initial_capacity => 2)
        end
        @class_to_pool = ThreadSafe::Cache.new(:initial_capacity => 2) do |h,k|
          h[k] = ThreadSafe::Cache.new
        end
      end

      def connection_pool_list
        owner_to_pool.values.compact
      end

      def connection_pools
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          In the next release, this will return the same as `#connection_pool_list`.
          (An array of pools, rather than a hash mapping specs to pools.)
        MSG

        Hash[connection_pool_list.map { |pool| [pool.spec, pool] }]
      end

      def establish_connection(owner, spec)
        @class_to_pool.clear
        raise RuntimeError, "Anonymous class is not allowed." unless owner.name
        owner_to_pool[owner.name] = ConnectionAdapters::ConnectionPool.new(spec)
      end

      def active_connections?
        connection_pool_list.any?(&:active_connection?)
      end

      def clear_active_connections!
        connection_pool_list.each(&:release_connection)
      end

      def clear_reloadable_connections!
        connection_pool_list.each(&:clear_reloadable_connections!)
      end

      def clear_all_connections!
        connection_pool_list.each(&:disconnect!)
      end

      def retrieve_connection(klass) #:nodoc:
        pool = retrieve_connection_pool(klass)
        raise ConnectionNotEstablished, "No connection pool for #{klass}" unless pool
        conn = pool.connection
        raise ConnectionNotEstablished, "No connection for #{klass} in connection pool" unless conn
        conn
      end

      def connected?(klass)
        conn = retrieve_connection_pool(klass)
        conn && conn.connected?
      end

      def remove_connection(owner)
        if pool = owner_to_pool.delete(owner.name)
          @class_to_pool.clear
          pool.automatic_reconnect = false
          pool.disconnect!
          pool.spec.config
        end
      end

      def retrieve_connection_pool(klass)
        class_to_pool[klass.name] ||= begin
          until pool = pool_for(klass)
            klass = klass.superclass
            break unless klass <= Base
          end

          class_to_pool[klass.name] = pool
        end
      end

      private

      def owner_to_pool
        @owner_to_pool[Process.pid]
      end

      def class_to_pool
        @class_to_pool[Process.pid]
      end

      def pool_for(owner)
        owner_to_pool.fetch(owner.name) {
          if ancestor_pool = pool_from_any_process_for(owner)
            establish_connection owner, ancestor_pool.spec
          else
            owner_to_pool[owner.name] = nil
          end
        }
      end

      def pool_from_any_process_for(owner)
        owner_to_pool = @owner_to_pool.values.find { |v| v[owner.name] }
        owner_to_pool && owner_to_pool[owner.name]
      end
    end

    class ConnectionManagement
      def initialize(app)
        @app = app
      end

      def call(env)
        testing = env['rack.test']

        response = @app.call(env)
        response[2] = ::Rack::BodyProxy.new(response[2]) do
          ActiveRecord::Base.clear_active_connections! unless testing
        end

        response
      rescue Exception
        ActiveRecord::Base.clear_active_connections! unless testing
        raise
      end
    end
  end
end
