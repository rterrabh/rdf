require 'pathname'

class Pathname

  alias_method :to_str, :to_s unless method_defined?(:to_str)
end
