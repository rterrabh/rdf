require 'active_support/dependencies'

module AbstractController
  module Helpers
    extend ActiveSupport::Concern

    included do
      class_attribute :_helpers
      self._helpers = Module.new

      class_attribute :_helper_methods
      self._helper_methods = Array.new
    end

    class MissingHelperError < LoadError
      def initialize(error, path)
        @error = error
        @path  = "helpers/#{path}.rb"
        set_backtrace error.backtrace

        if error.path =~ /^#{path}(\.rb)?$/
          super("Missing helper file helpers/%s.rb" % path)
        else
          raise error
        end
      end
    end

    module ClassMethods
      def inherited(klass)
        helpers = _helpers
        klass._helpers = Module.new { include helpers }
        #nodyna <class_eval-1321> <CE COMPLEX (block execution)>
        klass.class_eval { default_helper_module! } unless klass.anonymous?
        super
      end

      def helper_method(*meths)
        meths.flatten!
        self._helper_methods += meths

        meths.each do |meth|
          #nodyna <class_eval-1322> <CE COMPLEX (define methods)>
          _helpers.class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def #{meth}(*args, &blk)                               # def current_user(*args, &blk)
              #nodyna <send-1323> <SD COMPLEX (change-prone variable)>
              controller.send(%(#{meth}), *args, &blk)             #   controller.send(:current_user, *args, &blk)
            end                                                    # end
          ruby_eval
        end
      end

      def helper(*args, &block)
        modules_for_helpers(args).each do |mod|
          add_template_helper(mod)
        end

        #nodyna <module_eval-1325> <ME COMPLEX (define methods)>
        _helpers.module_eval(&block) if block_given?
      end

      def clear_helpers
        inherited_helper_methods = _helper_methods
        self._helpers = Module.new
        self._helper_methods = Array.new

        inherited_helper_methods.each { |meth| helper_method meth }
        default_helper_module! unless anonymous?
      end

      def modules_for_helpers(args)
        args.flatten.map! do |arg|
          case arg
          when String, Symbol
            file_name = "#{arg.to_s.underscore}_helper"
            begin
              require_dependency(file_name)
            rescue LoadError => e
              raise AbstractController::Helpers::MissingHelperError.new(e, file_name)
            end

            mod_name = file_name.camelize
            begin
              mod_name.constantize
            rescue LoadError
              raise NameError, "Couldn't find #{mod_name}, expected it to be defined in helpers/#{file_name}.rb"
            end
          when Module
            arg
          else
            raise ArgumentError, "helper must be a String, Symbol, or Module"
          end
        end
      end

      private
      def add_template_helper(mod)
        #nodyna <module_eval-1326> <ME TRIVIAL (block execution)>
        _helpers.module_eval { include mod }
      end

      def default_helper_module!
        module_name = name.sub(/Controller$/, '')
        module_path = module_name.underscore
        helper module_path
      rescue MissingSourceFile => e
        raise e unless e.is_missing? "helpers/#{module_path}_helper"
      rescue NameError => e
        raise e unless e.missing_name? "#{module_name}Helper"
      end
    end
  end
end
