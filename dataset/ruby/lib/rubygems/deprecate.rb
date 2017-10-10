
module Gem::Deprecate

  def self.skip # :nodoc:
    @skip ||= false
  end

  def self.skip= v # :nodoc:
    @skip = v
  end


  def skip_during
    Gem::Deprecate.skip, original = true, Gem::Deprecate.skip
    yield
  ensure
    Gem::Deprecate.skip = original
  end


  def deprecate name, repl, year, month
    #nodyna <class_eval-2315> <not yet classified>
    class_eval {
      old = "_deprecated_#{name}"
      alias_method old, name
      #nodyna <define_method-2316> <DM COMPLEX (events)>
      define_method name do |*args, &block|
        klass = self.kind_of? Module
        target = klass ? "#{self}." : "#{self.class}#"
        msg = [ "NOTE: #{target}#{name} is deprecated",
          repl == :none ? " with no replacement" : "; use #{repl} instead",
          ". It will be removed on or after %4d-%02d-01." % [year, month],
          "\n#{target}#{name} called from #{Gem.location_of_caller.join(":")}",
        ]
        warn "#{msg.join}." unless Gem::Deprecate.skip
        #nodyna <send-2317> <SD COMPLEX (change-prone variables)>
        send old, *args, &block
      end
    }
  end

  module_function :deprecate, :skip_during

end

