module ActiveModel
  class ForbiddenAttributesError < StandardError
  end

  module ForbiddenAttributesProtection # :nodoc:
    protected
      def sanitize_for_mass_assignment(attributes)
        if attributes.respond_to?(:permitted?) && !attributes.permitted?
          raise ActiveModel::ForbiddenAttributesError
        else
          attributes
        end
      end
      alias :sanitize_forbidden_attributes :sanitize_for_mass_assignment
  end
end
