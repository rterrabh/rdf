require 'active_support/core_ext/hash/keys'

module ActionDispatch
  class Request < Rack::Request
    def flash
      @env[Flash::KEY] ||= Flash::FlashHash.from_session_value(session["flash"])
    end
  end

  class Flash
    KEY = 'action_dispatch.request.flash_hash'.freeze

    class FlashNow #:nodoc:
      attr_accessor :flash

      def initialize(flash)
        @flash = flash
      end

      def []=(k, v)
        k = k.to_s
        @flash[k] = v
        @flash.discard(k)
        v
      end

      def [](k)
        @flash[k.to_s]
      end

      def alert=(message)
        self[:alert] = message
      end

      def notice=(message)
        self[:notice] = message
      end
    end

    class FlashHash
      include Enumerable

      def self.from_session_value(value) #:nodoc:
        flash = case value
                when FlashHash # Rails 3.1, 3.2
                  #nodyna <instance_variable_get-1235> <IVG MODERATE (private access)>
                  #nodyna <instance_variable_get-1236> <IVG MODERATE (private access)>
                  new(value.instance_variable_get(:@flashes), value.instance_variable_get(:@used))
                when Hash # Rails 4.0
                  new(value['flashes'], value['discard'])
                else
                  new
                end

        flash.tap(&:sweep)
      end
      
      def to_session_value #:nodoc:
        return nil if empty?
        {'discard' => @discard.to_a, 'flashes' => @flashes}
      end

      def initialize(flashes = {}, discard = []) #:nodoc:
        @discard = Set.new(stringify_array(discard))
        @flashes = flashes.stringify_keys
        @now     = nil
      end

      def initialize_copy(other)
        if other.now_is_loaded?
          @now = other.now.dup
          @now.flash = self
        end
        super
      end

      def []=(k, v)
        k = k.to_s
        @discard.delete k
        @flashes[k] = v
      end

      def [](k)
        @flashes[k.to_s]
      end

      def update(h) #:nodoc:
        @discard.subtract stringify_array(h.keys)
        @flashes.update h.stringify_keys
        self
      end

      def keys
        @flashes.keys
      end

      def key?(name)
        @flashes.key? name.to_s
      end

      def delete(key)
        key = key.to_s
        @discard.delete key
        @flashes.delete key
        self
      end

      def to_hash
        @flashes.dup
      end

      def empty?
        @flashes.empty?
      end

      def clear
        @discard.clear
        @flashes.clear
      end

      def each(&block)
        @flashes.each(&block)
      end

      alias :merge! :update

      def replace(h) #:nodoc:
        @discard.clear
        @flashes.replace h.stringify_keys
        self
      end

      def now
        @now ||= FlashNow.new(self)
      end

      def keep(k = nil)
        k = k.to_s if k
        @discard.subtract Array(k || keys)
        k ? self[k] : self
      end

      def discard(k = nil)
        k = k.to_s if k
        @discard.merge Array(k || keys)
        k ? self[k] : self
      end

      def sweep #:nodoc:
        @discard.each { |k| @flashes.delete k }
        @discard.replace @flashes.keys
      end

      def alert
        self[:alert]
      end

      def alert=(message)
        self[:alert] = message
      end

      def notice
        self[:notice]
      end

      def notice=(message)
        self[:notice] = message
      end

      protected
      def now_is_loaded?
        @now
      end

      def stringify_array(array)
        array.map do |item|
          item.kind_of?(Symbol) ? item.to_s : item
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      session    = Request::Session.find(env) || {}
      flash_hash = env[KEY]

      if flash_hash && (flash_hash.present? || session.key?('flash'))
        session["flash"] = flash_hash.to_session_value
        env[KEY] = flash_hash.dup
      end

      if (!session.respond_to?(:loaded?) || session.loaded?) && # (reset_session uses {}, which doesn't implement #loaded?)
        session.key?('flash') && session['flash'].nil?
        session.delete('flash')
      end
    end
  end
end
