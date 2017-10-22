module ActiveSupport
  module Concern
    class MultipleIncludedBlocks < StandardError #:nodoc:
      def initialize
        super "Cannot define multiple 'included' blocks for a Concern"
      end
    end

    def self.extended(base) #:nodoc:
      #nodyna <instance_variable_set-1134> <IVS COMPLEX (variable definition)>
      base.instance_variable_set(:@_dependencies, [])
    end

    def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        #nodyna <instance_variable_get-1135> <IVG COMPLEX (private access)>
        base.instance_variable_get(:@_dependencies) << self
        return false
      else
        return false if base < self
        #nodyna <send-1136> <SD TRIVIAL (public methods)>
        @_dependencies.each { |dep| base.send(:include, dep) }
        super
        #nodyna <const_get-1137> <CG TRIVIAL (static values)>
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        #nodyna <class_eval-1138> <CE COMPLEX (block execution)>
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end

    def included(base = nil, &block)
      if base.nil?
        raise MultipleIncludedBlocks if instance_variable_defined?(:@_included_block)

        @_included_block = block
      else
        super
      end
    end

    def class_methods(&class_methods_module_definition)
      mod = const_defined?(:ClassMethods, false) ?
        #nodyna <const_get-1139> <CG TRIVIAL (static values)>
        const_get(:ClassMethods) :
        #nodyna <const_set-1140> <CS TRIVIAL (static values)>
        const_set(:ClassMethods, Module.new)

      #nodyna <module_eval-1141> <ME COMPLEX (block execution)>
      mod.module_eval(&class_methods_module_definition)
    end
  end
end
