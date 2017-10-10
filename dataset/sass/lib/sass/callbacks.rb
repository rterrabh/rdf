module Sass
  module Callbacks
    def self.extended(base)
      #nodyna <send-2970> <SD TRIVIAL (public functions)>
      base.send(:include, InstanceMethods)
    end

    protected

    module InstanceMethods
      def clear_callbacks!
        @_sass_callbacks = {}
      end
    end

    def define_callback(name)
      #nodyna <class_eval-2971> <CE MODERATE (define methods)>
      class_eval <<RUBY, __FILE__, __LINE__ + 1
def on_#{name}(&block)
  @_sass_callbacks ||= {}
  (@_sass_callbacks[#{name.inspect}] ||= []) << block
end

def run_#{name}(*args)
  return unless @_sass_callbacks
  return unless @_sass_callbacks[#{name.inspect}]
  @_sass_callbacks[#{name.inspect}].each {|c| c[*args]}
end
private :run_#{name}
RUBY
    end
  end
end
