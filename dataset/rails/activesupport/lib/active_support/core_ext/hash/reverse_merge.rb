class Hash
  def reverse_merge(other_hash)
    other_hash.merge(self)
  end

  def reverse_merge!(other_hash)
    merge!( other_hash ){|key,left,right| left }
  end
  alias_method :reverse_update, :reverse_merge!
end
