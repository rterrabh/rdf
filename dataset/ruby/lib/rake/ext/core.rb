class Module
  def rake_extension(method) # :nodoc:
    if method_defined?(method)
      $stderr.puts "WARNING: Possible conflict with Rake extension: " +
        "#{self}##{method} already exists"
    else
      yield
    end
  end
end
