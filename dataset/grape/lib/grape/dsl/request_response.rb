require 'active_support/concern'

module Grape
  module DSL
    module RequestResponse
      extend ActiveSupport::Concern

      include Grape::DSL::Configuration

      module ClassMethods
        def default_format(new_format = nil)
          namespace_inheritable(:default_format, new_format.nil? ? nil : new_format.to_sym)
        end

        def format(new_format = nil)
          if new_format
            namespace_inheritable(:format, new_format.to_sym)
            namespace_inheritable(:default_error_formatter, Grape::ErrorFormatter::Base.formatter_for(new_format, {}))
            mime_type = content_types[new_format.to_sym]
            fail Grape::Exceptions::MissingMimeType.new(new_format) unless mime_type
            namespace_stackable(:content_types, new_format.to_sym => mime_type)
          else
            namespace_inheritable(:format)
          end
        end

        def formatter(content_type, new_formatter)
          namespace_stackable(:formatters, content_type.to_sym => new_formatter)
        end

        def parser(content_type, new_parser)
          namespace_stackable(:parsers, content_type.to_sym => new_parser)
        end

        def default_error_formatter(new_formatter_name = nil)
          if new_formatter_name
            new_formatter = Grape::ErrorFormatter::Base.formatter_for(new_formatter_name, {})
            namespace_inheritable(:default_error_formatter, new_formatter)
          else
            namespace_inheritable(:default_error_formatter)
          end
        end

        def error_formatter(format, options)
          if options.is_a?(Hash) && options.key?(:with)
            formatter = options[:with]
          else
            formatter = options
          end

          namespace_stackable(:error_formatters, format.to_sym => formatter)
        end

        def content_type(key, val)
          namespace_stackable(:content_types, key.to_sym => val)
        end

        def content_types
          c_types = Grape::DSL::Configuration.stacked_hash_to_hash(namespace_stackable(:content_types))
          Grape::ContentTypes.content_types_for c_types
        end

        def default_error_status(new_status = nil)
          namespace_inheritable(:default_error_status, new_status)
        end

        def rescue_from(*args, &block)
          if args.last.is_a?(Proc)
            handler = args.pop
          elsif block_given?
            handler = block
          end

          options = args.last.is_a?(Hash) ? args.pop : {}
          handler ||= proc { options[:with] } if options.key?(:with)

          if args.include?(:all)
            namespace_inheritable(:rescue_all, true)
            namespace_inheritable :all_rescue_handler, handler
          else
            handler_type =
                case options[:rescue_subclasses]
                when nil, true
                  :rescue_handlers
                else
                  :base_only_rescue_handlers
                end

            namespace_stackable handler_type, Hash[args.map { |arg| [arg, handler] }]
          end

          namespace_stackable(:rescue_options, options)
        end

        def represent(model_class, options)
          fail Grape::Exceptions::InvalidWithOptionForRepresent.new unless options[:with] && options[:with].is_a?(Class)
          namespace_stackable(:representations, model_class => options[:with])
        end
      end
    end
  end
end
