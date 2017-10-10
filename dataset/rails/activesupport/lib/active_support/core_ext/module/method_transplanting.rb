class Module
  def methods_transplantable? # :nodoc:
    x = Module.new { def foo; end }
    #nodyna <define_method-1042> <DM MODERATE (events)>
    Module.new { define_method :bar, x.instance_method(:foo) }
    true
  rescue TypeError
    false
  end
end
