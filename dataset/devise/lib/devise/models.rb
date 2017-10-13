module Devise
  module Models
    class MissingAttribute < StandardError
      def initialize(attributes)
        @attributes = attributes
      end

      def message
        "The following attribute(s) is (are) missing on your model: #{@attributes.join(", ")}"
      end
    end

    def self.config(mod, *accessors) #:nodoc:
      class << mod; attr_accessor :available_configs; end
      mod.available_configs = accessors

      accessors.each do |accessor|
        #nodyna <class_eval-2761> <CE MODERATE (define methods)>
        mod.class_eval <<-METHOD, __FILE__, __LINE__ + 1
          def #{accessor}
            if defined?(@#{accessor})
              @#{accessor}
            elsif superclass.respond_to?(:#{accessor})
              superclass.#{accessor}
            else
              Devise.#{accessor}
            end
          end

          def #{accessor}=(value)
            @#{accessor} = value
          end
        METHOD
      end
    end

    def self.check_fields!(klass)
      failed_attributes = []
      instance = klass.new

      klass.devise_modules.each do |mod|
        #nodyna <const_get-2762> <CG COMPLEX (array)>
        constant = const_get(mod.to_s.classify)

        constant.required_fields(klass).each do |field|
          failed_attributes << field unless instance.respond_to?(field)
        end
      end

      if failed_attributes.any?
        fail Devise::Models::MissingAttribute.new(failed_attributes)
      end
    end

    def devise(*modules)
      options = modules.extract_options!.dup

      selected_modules = modules.map(&:to_sym).uniq.sort_by do |s|
        Devise::ALL.index(s) || -1  # follow Devise::ALL order
      end

      devise_modules_hook! do
        include Devise::Models::Authenticatable

        selected_modules.each do |m|
          #nodyna <const_get-2763> <CG COMPLEX (array)>
          mod = Devise::Models.const_get(m.to_s.classify)

          if mod.const_defined?("ClassMethods")
            #nodyna <const_get-2764> <CG COMPLEX (static values)>
            class_mod = mod.const_get("ClassMethods")
            extend class_mod

            if class_mod.respond_to?(:available_configs)
              available_configs = class_mod.available_configs
              available_configs.each do |config|
                next unless options.key?(config)
                #nodyna <send-2765> <SD COMPLEX (array)>
                send(:"#{config}=", options.delete(config))
              end
            end
          end

          include mod
        end

        self.devise_modules |= selected_modules
        #nodyna <send-2766> <SD COMPLEX (array)>
        options.each { |key, value| send(:"#{key}=", value) }
      end
    end

    def devise_modules_hook!
      yield
    end
  end
end

require 'devise/models/authenticatable'
