require 'active_support/hash_with_indifferent_access'

class Hash

  def with_indifferent_access
    ActiveSupport::HashWithIndifferentAccess.new_from_hash_copying_default(self)
  end

  alias nested_under_indifferent_access with_indifferent_access
end
