module RailsAdmin
  module Config
    module HasFields
      def field(name, type = nil, add_to_section = true, &block)
        field = _fields.detect { |f| name == f.name }

        if field
          #nodyna <instance_variable_get-1378> <not yet classified>
          field.show unless field.instance_variable_get("@#{field.name}_registered").is_a?(Proc)
        end
        if field.nil? && type.nil?
          field = (_fields << RailsAdmin::Config::Fields::Types.load(:string).new(self, name, nil)).last

        elsif type && type != (field.nil? ? nil : field.type)
          if field
            properties = field.properties
            _fields.delete(field)
          else
            properties = abstract_model.properties.detect { |p| name == p.name }
          end
          field = (_fields << RailsAdmin::Config::Fields::Types.load(type).new(self, name, properties)).last
        end

        if add_to_section && !field.defined
          field.defined = true
          field.order = _fields.count(&:defined)
        end

        #nodyna <instance_eval-1379> <IEV COMPLEX (block execution)>
        field.instance_eval(&block) if block
        field
      end

      def configure(name, type = nil, &block)
        field(name, type, false, &block)
      end

      def include_fields(*field_names, &block)
        if field_names.empty?
          #nodyna <instance_eval-1380> <IEV COMPLEX (block execution)>
          _fields.select { |f| f.instance_eval(&block) }.each do |f|
            next if f.defined
            f.defined = true
            f.order = _fields.count(&:defined)
          end
        else
          fields(*field_names, &block)
        end
      end

      def exclude_fields(*field_names, &block)
        block ||= proc { |f| field_names.include?(f.name) }
        _fields.each { |f| f.defined = true } if _fields.select(&:defined).empty?
        #nodyna <instance_eval-1381> <IEV COMPLEX (block execution)>
        _fields.select { |f| f.instance_eval(&block) }.each { |f| f.defined = false }
      end

      alias_method :exclude_fields_if, :exclude_fields
      alias_method :include_fields_if, :include_fields

      def include_all_fields
        include_fields_if { true }
      end

      def fields(*field_names, &block)
        return all_fields if field_names.empty? && !block

        if field_names.empty?
          defined = _fields.select(&:defined)
          defined = _fields if defined.empty?
        else
          defined = field_names.collect { |field_name| _fields.detect { |f| f.name == field_name } }
        end
        defined.collect do |f|
          unless f.defined
            f.defined = true
            f.order = _fields.count(&:defined)
          end
          #nodyna <instance_eval-1382> <IEV COMPLEX (block execution)>
          f.instance_eval(&block) if block
          f
        end
      end

      def fields_of_type(type, &block)
        #nodyna <instance_eval-1383> <IEV COMPLEX (block execution)>
        _fields.select { |f| type == f.type }.map! { |f| f.instance_eval(&block) } if block
      end

      def all_fields
        ((ro_fields = _fields(true)).select(&:defined).presence || ro_fields).collect do |f|
          f.section = self
          f
        end
      end

      def visible_fields
        i = 0
        all_fields.collect { |f| f.with(bindings) }.select(&:visible?).sort_by { |f| [f.order, i += 1] } # stable sort, damn
      end

    protected

      def _fields(readonly = false)
        return @_fields if @_fields
        return @_ro_fields if readonly && @_ro_fields

        if self.class == RailsAdmin::Config::Sections::Base
          @_ro_fields = @_fields = RailsAdmin::Config::Fields.factory(self)
        else
          #nodyna <send-1384> <SD COMPLEX (change-prone variables)>
          @_ro_fields ||= parent.send(self.class.superclass.to_s.underscore.split('/').last)._fields(true).freeze
        end
        readonly ? @_ro_fields : (@_fields ||= @_ro_fields.collect(&:clone))
      end
    end
  end
end
