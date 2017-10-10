require 'active_support/concern'
require 'active_support/ordered_options'
require 'active_support/core_ext/array/extract_options'

module ActiveSupport
  module Configurable
    extend ActiveSupport::Concern

    class Configuration < ActiveSupport::InheritableOptions
      def compile_methods!
        self.class.compile_methods!(keys)
      end

      def self.compile_methods!(keys)
        keys.reject { |m| method_defined?(m) }.each do |key|
          #nodyna <class_eval-1025> <not yet classified>
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{key}; _get(#{key.inspect}); end
          RUBY
        end
      end
    end

    module ClassMethods
      def config
        @_config ||= if respond_to?(:superclass) && superclass.respond_to?(:config)
          superclass.config.inheritable_copy
        else
          Class.new(Configuration).new
        end
      end

      def configure
        yield config
      end

      def config_accessor(*names)
        options = names.extract_options!

        names.each do |name|
          raise NameError.new('invalid config attribute name') unless name =~ /\A[_A-Za-z]\w*\z/

          reader, reader_line = "def #{name}; config.#{name}; end", __LINE__
          writer, writer_line = "def #{name}=(value); config.#{name} = value; end", __LINE__

          #nodyna <class_eval-1026> <not yet classified>
          singleton_class.class_eval reader, __FILE__, reader_line
          #nodyna <class_eval-1027> <not yet classified>
          singleton_class.class_eval writer, __FILE__, writer_line

          unless options[:instance_accessor] == false
            #nodyna <class_eval-1028> <not yet classified>
            class_eval reader, __FILE__, reader_line unless options[:instance_reader] == false
            #nodyna <class_eval-1029> <not yet classified>
            class_eval writer, __FILE__, writer_line unless options[:instance_writer] == false
          end
          #nodyna <send-1030> <SD MODERATE (array)>
          send("#{name}=", yield) if block_given?
        end
      end
    end

    def config
      @_config ||= self.class.config.inheritable_copy
    end
  end
end

