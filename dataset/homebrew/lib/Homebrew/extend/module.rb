class Module
  def attr_rw(*attrs)
    file, line, = caller.first.split(":")
    line = line.to_i

    attrs.each do |attr|
      #nodyna <module_eval-678> <not yet classified>
      module_eval <<-EOS, file, line
        def #{attr}(val=nil)
          val.nil? ? @#{attr} : @#{attr} = val
        end
      EOS
    end
  end
end
