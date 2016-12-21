##
# Creates methods on object which delegate to an association proxy.
# see delegate_belongs_to for two uses
#
# Todo - integrate with ActiveRecord::Dirty to make sure changes to delegate object are noticed
# Should do
# class User < Spree::Base; delegate_belongs_to :contact, :firstname; end
# class Contact < Spree::Base; end
# u = User.first
# u.changed? # => false
# u.firstname = 'Bobby'
# u.changed? # => true
#
# Right now the second call to changed? would return false
#
# Todo - add has_one support. fairly straightforward addition
##
module DelegateBelongsTo
  extend ActiveSupport::Concern

  module ClassMethods

    @@default_rejected_delegate_columns = ['created_at','created_on','updated_at','updated_on','lock_version','type','id','position','parent_id','lft','rgt']
    mattr_accessor :default_rejected_delegate_columns

    ##
    # Creates methods for accessing and setting attributes on an association.  Uses same
    # default list of attributes as delegates_to_association.
    # @todo Integrate this with ActiveRecord::Dirty, so if you set a property through one of these setters and then call save on this object, it will save the associated object automatically.
    # delegate_belongs_to :contact
    # delegate_belongs_to :contact, [:defaults]  ## same as above, and useless
    # delegate_belongs_to :contact, [:defaults, :address, :fullname], :class_name => 'VCard'
    ##
    def delegate_belongs_to(association, *attrs)
      opts = attrs.extract_options!
      initialize_association :belongs_to, association, opts
      attrs = get_association_column_names(association) if attrs.empty?
      attrs.concat get_association_column_names(association) if attrs.delete :defaults
      attrs.each do |attr|
        class_def attr do |*args|
          #nodyna <ID:send-7> <send LOW ex4>
          send(:delegator_for, association, attr, *args)
        end

        class_def "#{attr}=" do |val|
          #nodyna <ID:send-8> <send LOW ex4>
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

      ##
      # initialize_association :belongs_to, :contact
      def initialize_association(type, association, opts={})
        raise 'Illegal or unimplemented association type.' unless [:belongs_to].include?(type.to_s.to_sym)
        #nodyna <ID:send-9> <send MEDIUM ex3>
        send type, association, opts if reflect_on_association(association).nil?
      end

    private
      def class_def(name, method=nil, &blk)
        #nodyna <ID:define_method-3> <define_method VERY HIGH ex2>
        #nodyna <ID:define_method-3> <define_method VERY HIGH ex2>
        class_eval { method.nil? ? define_method(name, &blk) : define_method(name, method) }
      end
  end

  def delegator_for(association, attr, *args)
    return if self.class.column_names.include?(attr.to_s)
    #nodyna <ID:send-10> <send MEDIUM ex3>
    send("#{association}=", self.class.reflect_on_association(association).klass.new) if send(association).nil?
    if args.empty?
      #nodyna <ID:send-11> <send MEDIUM ex3>
      send(association).send(attr)
    else
      #nodyna <ID:send-12> <send MEDIUM ex3>
      send(association).send(attr, *args)
    end
  end

  def delegator_for_setter(association, attr, val)
    return if self.class.column_names.include?(attr.to_s)
    #nodyna <ID:send-13> <send MEDIUM ex3>
    send("#{association}=", self.class.reflect_on_association(association).klass.new) if send(association).nil?
    #nodyna <ID:send-14> <send MEDIUM ex3>
    send(association).send("#{attr}=", val)
  end
  protected :delegator_for
  protected :delegator_for_setter
end

#nodyna <ID:send-15> <send VERY LOW ex1>
ActiveRecord::Base.send :include, DelegateBelongsTo
