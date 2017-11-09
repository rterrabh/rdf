class Test
  def bar
    x = Z.new
    if x.send(:foo)
      y = 3
    end
  end
end
