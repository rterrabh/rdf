module Shim
  extend ::ActiveSupport::Concern

  included do
    include ::Mongoid::Timestamps
    field :created_at, type: DateTime
  end

  module ClassMethods
    def order(attribute)
      asc(attribute)
    end

    def find_by_email(email)
      find_by(email: email)
    end
  end

  def ==(other)
    other.is_a?(self.class) && _id == other._id
  end
end