class Object
  def acts_like?(duck)
    respond_to? :"acts_like_#{duck}?"
  end
end
