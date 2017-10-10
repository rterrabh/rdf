require 'rake'

module Rake

  class TaskLib
    include Cloneable
    include Rake::DSL

    def paste(a, b)             # :nodoc:
      (a.to_s + b.to_s).intern
    end
  end

end
