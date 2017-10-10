require 'rake/ext/core'
require 'pathname'

class Pathname

  rake_extension("ext") do
    def ext(newext='')
      Pathname.new(Rake.from_pathname(self).ext(newext))
    end
  end

  rake_extension("pathmap") do
    def pathmap(spec=nil, &block)
      Pathname.new(Rake.from_pathname(self).pathmap(spec, &block))
    end
  end
end
