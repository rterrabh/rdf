require 'action_controller/model_naming'

module ActionDispatch
  module Routing
    module PolymorphicRoutes
      include ActionController::ModelNaming

      def polymorphic_url(record_or_hash_or_array, options = {})
        if Hash === record_or_hash_or_array
          options = record_or_hash_or_array.merge(options)
          record  = options.delete :id
          return polymorphic_url record, options
        end

        opts   = options.dup
        action = opts.delete :action
        type   = opts.delete(:routing_type) || :url

        HelperMethodBuilder.polymorphic_method self,
                                               record_or_hash_or_array,
                                               action,
                                               type,
                                               opts
      end

      def polymorphic_path(record_or_hash_or_array, options = {})
        if Hash === record_or_hash_or_array
          options = record_or_hash_or_array.merge(options)
          record  = options.delete :id
          return polymorphic_path record, options
        end

        opts   = options.dup
        action = opts.delete :action
        type   = :path

        HelperMethodBuilder.polymorphic_method self,
                                               record_or_hash_or_array,
                                               action,
                                               type,
                                               opts
      end


      %w(edit new).each do |action|
        #nodyna <module_eval-1279> <not yet classified>
        module_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{action}_polymorphic_url(record_or_hash, options = {})
            polymorphic_url_for_action("#{action}", record_or_hash, options)
          end

          def #{action}_polymorphic_path(record_or_hash, options = {})
            polymorphic_path_for_action("#{action}", record_or_hash, options)
          end
        EOT
      end

      private

      def polymorphic_url_for_action(action, record_or_hash, options)
        polymorphic_url(record_or_hash, options.merge(:action => action))
      end

      def polymorphic_path_for_action(action, record_or_hash, options)
        polymorphic_path(record_or_hash, options.merge(:action => action))
      end

      class HelperMethodBuilder # :nodoc:
        CACHE = { 'path' => {}, 'url' => {} }

        def self.get(action, type)
          type   = type.to_s
          CACHE[type].fetch(action) { build action, type }
        end

        def self.url;  CACHE['url'.freeze][nil]; end
        def self.path; CACHE['path'.freeze][nil]; end

        def self.build(action, type)
          prefix = action ? "#{action}_" : ""
          suffix = type
          if action.to_s == 'new'
            HelperMethodBuilder.singular prefix, suffix
          else
            HelperMethodBuilder.plural prefix, suffix
          end
        end

        def self.singular(prefix, suffix)
          new(->(name) { name.singular_route_key }, prefix, suffix)
        end

        def self.plural(prefix, suffix)
          new(->(name) { name.route_key }, prefix, suffix)
        end

        def self.polymorphic_method(recipient, record_or_hash_or_array, action, type, options)
          builder = get action, type

          case record_or_hash_or_array
          when Array
            record_or_hash_or_array = record_or_hash_or_array.compact
            if record_or_hash_or_array.empty?
              raise ArgumentError, "Nil location provided. Can't build URI."
            end
            if record_or_hash_or_array.first.is_a?(ActionDispatch::Routing::RoutesProxy)
              recipient = record_or_hash_or_array.shift
            end

            method, args = builder.handle_list record_or_hash_or_array
          when String, Symbol
            method, args = builder.handle_string record_or_hash_or_array
          when Class
            method, args = builder.handle_class record_or_hash_or_array

          when nil
            raise ArgumentError, "Nil location provided. Can't build URI."
          else
            method, args = builder.handle_model record_or_hash_or_array
          end


          if options.empty?
            #nodyna <send-1280> <SD COMPLEX (change-prone variables)>
            recipient.send(method, *args)
          else
            #nodyna <send-1281> <SD COMPLEX (change-prone variables)>
            recipient.send(method, *args, options)
          end
        end

        attr_reader :suffix, :prefix

        def initialize(key_strategy, prefix, suffix)
          @key_strategy = key_strategy
          @prefix       = prefix
          @suffix       = suffix
        end

        def handle_string(record)
          [get_method_for_string(record), []]
        end

        def handle_string_call(target, str)
          #nodyna <send-1282> <SD COMPLEX (change-prone variables)>
          target.send get_method_for_string str
        end

        def handle_class(klass)
          [get_method_for_class(klass), []]
        end

        def handle_class_call(target, klass)
          #nodyna <send-1283> <SD COMPLEX (change-prone variables)>
          target.send get_method_for_class klass
        end

        def handle_model(record)
          args  = []

          model = record.to_model
          name = if model.persisted?
                   args << model
                   model.model_name.singular_route_key
                 else
                   @key_strategy.call model.model_name
                 end

          named_route = prefix + "#{name}_#{suffix}"

          [named_route, args]
        end

        def handle_model_call(target, model)
          method, args = handle_model model
          #nodyna <send-1284> <SD COMPLEX (change-prone variables)>
          target.send(method, *args)
        end

        def handle_list(list)
          record_list = list.dup
          record      = record_list.pop

          args = []

          route  = record_list.map { |parent|
            case parent
            when Symbol, String
              parent.to_s
            when Class
              args << parent
              parent.model_name.singular_route_key
            else
              args << parent.to_model
              parent.to_model.model_name.singular_route_key
            end
          }

          route <<
          case record
          when Symbol, String
            record.to_s
          when Class
            @key_strategy.call record.model_name
          else
            model = record.to_model
            if model.persisted?
              args << model
              model.model_name.singular_route_key
            else
              @key_strategy.call model.model_name
            end
          end

          route << suffix

          named_route = prefix + route.join("_")
          [named_route, args]
        end

        private

        def get_method_for_class(klass)
          name   = @key_strategy.call klass.model_name
          prefix + "#{name}_#{suffix}"
        end

        def get_method_for_string(str)
          prefix + "#{str}_#{suffix}"
        end

        [nil, 'new', 'edit'].each do |action|
          CACHE['url'][action]  = build action, 'url'
          CACHE['path'][action] = build action, 'path'
        end
      end
    end
  end
end
