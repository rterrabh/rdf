
module IRB # :nodoc:
  class Context

    def home_workspace
      if defined? @home_workspace
        @home_workspace
      else
        @home_workspace = @workspace
      end
    end

    def change_workspace(*_main)
      if _main.empty?
        @workspace = home_workspace
        return main
      end

      @workspace = WorkSpace.new(_main[0])

      if !(class<<main;ancestors;end).include?(ExtendCommandBundle)
        main.extend ExtendCommandBundle
      end
    end
  end
end

