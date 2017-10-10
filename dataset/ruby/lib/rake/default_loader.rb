module Rake

  class DefaultLoader


    def load(fn)
      Rake.load_rakefile(File.expand_path(fn))
    end
  end

end
