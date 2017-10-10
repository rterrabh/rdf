require 'rails/generators/active_model'
require 'rails/generators/model_helpers'

module Rails
  module Generators
    module ResourceHelpers # :nodoc:

      def self.included(base) #:nodoc:
        #nodyna <send-1164> <SD TRIVIAL (public methods)>
        base.send :include, Rails::Generators::ModelHelpers
        base.class_option :model_name, type: :string, desc: "ModelName to be used"
      end

      def initialize(*args) #:nodoc:
        super
        controller_name = name
        if options[:model_name]
          self.name = options[:model_name]
          assign_names!(self.name)
        end

        assign_controller_names!(controller_name.pluralize)
      end

      protected

        attr_reader :controller_name, :controller_file_name

        def controller_class_path
          if options[:model_name]
            @controller_class_path
          else
            class_path
          end
        end

        def assign_controller_names!(name)
          @controller_name = name
          @controller_class_path = name.include?('/') ? name.split('/') : name.split('::')
          @controller_class_path.map! { |m| m.underscore }
          @controller_file_name = @controller_class_path.pop
        end

        def controller_file_path
          @controller_file_path ||= (controller_class_path + [controller_file_name]).join('/')
        end

        def controller_class_name
          (controller_class_path + [controller_file_name]).map!{ |m| m.camelize }.join('::')
        end

        def controller_i18n_scope
          @controller_i18n_scope ||= controller_file_path.tr('/', '.')
        end

        def orm_class
          @orm_class ||= begin
            unless self.class.class_options[:orm]
              raise "You need to have :orm as class option to invoke orm_class and orm_instance"
            end

            begin
              "#{options[:orm].to_s.camelize}::Generators::ActiveModel".constantize
            rescue NameError
              Rails::Generators::ActiveModel
            end
          end
        end

        def orm_instance(name=singular_table_name)
          @orm_instance ||= orm_class.new(name)
        end
    end
  end
end
