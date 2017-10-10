class Object
  unless respond_to?(:itself)
    def itself
      self
    end
  end
end
