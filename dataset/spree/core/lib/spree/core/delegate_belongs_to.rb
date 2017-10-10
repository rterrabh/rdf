module DelegateBelongsTo
  extend ActiveSupport::Concern

  module ClassMethods

    @@default_rejected_delegate_columns = ['created_at','created_on','updated_at','updated_on','lock_version','type','id','position','parent_id','lft','rgt']
    mattr_accessor :default_rejected_delegate_columns

    def delegate_belongs_to(association, *attrs)
      opts = attrs.extract_options!
      initialize_association :belongs_to, association, opts
      attrs = get_association_column_names(association) if attrs.empty?
      attrs.concat get_association_column_names(association) if attrs.delete :defaults
      attrs.each do |attr|
        class_def attr do |*args|
          #nodyna <send-2564> <SD EASY (private methods)>
          send(:delegator_for, association, attr, *args)
        end

        class_def "#{attr}=" do |val|
          #nodyna <send-2565> <SD EASY (private methods)>
          send(:delegator_for_setter, association, attr, val)
        end
      end
    end

    protected

      def get_association_column_names(association, without_default_rejected_delegate_columns=true)
        begin
          association_klass = reflect_on_association(association).klass
          methods = association_klass.column_names
          methods.reject!{|x|default_rejected_delegate_columns.include?(x.to_s)} if without_default_rejected_delegate_columns
          return methods
        rescue
          return []
        end
      end

      def initialize_association(type, association, opts={})
        raise 'Illegal or unimplemented association type.' unless [:belongs_to].include?(type.to_s.to_sym)
        #nodyna <send-2566> <SD MODERATE (change-prone variables)>
        send type, association, opts if reflect_on_association(association).nil?
      end

    private
      def class_def(name, method=nil, &blk)
        #nodyna <define_method-2567> <DM COMPLEX (events)>
        #nodyna <define_method-2568> <DM COMPLEX (events)>
        #nodyna <class_eval-2569> <not yet classified>
        class_eval { method.nil? ? define_method(name, &blk) : define_method(name, method) }
      end
  end

  def delegator_for(association, attr, *args)
    return if self.class.column_names.include?(attr.to_s)
    #nodyna <send-2570> <SD MODERATE (change-prone variables)>
    #nodyna <send-2571> <SD MODERATE (change-prone variables)>
    send("#{association}=", self.class.reflect_on_association(association).klass.new) if send(association).nil?
    if args.empty?
      #nodyna <send-2572> <SD MODERATE (change-prone variables)>
      #nodyna <send-2573> <SD MODERATE (change-prone variables)>
      send(association).send(attr)
    else
      #nodyna <send-2574> <SD MODERATE (change-prone variables)>
      #nodyna <send-2575> <SD MODERATE (change-prone variables)>
      send(association).send(attr, *args)
    end
  end

  def delegator_for_setter(association, attr, val)
    return if self.class.column_names.include?(attr.to_s)
    #nodyna <send-2576> <SD MODERATE (change-prone variables)>
    #nodyna <send-2577> <SD MODERATE (change-prone variables)>
    send("#{association}=", self.class.reflect_on_association(association).klass.new) if send(association).nil?
    #nodyna <send-2578> <SD MODERATE (change-prone variables)>
    #nodyna <send-2579> <SD MODERATE (change-prone variables)>
    send(association).send("#{attr}=", val)
  end
  protected :delegator_for
  protected :delegator_for_setter
end

#nodyna <send-2580> <SD TRIVIAL (public methods)>
ActiveRecord::Base.send :include, DelegateBelongsTo
