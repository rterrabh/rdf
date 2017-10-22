module Pod
  class Installer
    class Analyzer
      class SpecsState
        def initialize(pods_by_state = nil)
          @added     = []
          @deleted   = []
          @changed   = []
          @unchanged = []

          if pods_by_state
            @added     = pods_by_state[:added]     || []
            @deleted   = pods_by_state[:removed]   || []
            @changed   = pods_by_state[:changed]   || []
            @unchanged = pods_by_state[:unchanged] || []
          end
        end

        attr_accessor :added

        attr_accessor :changed

        attr_accessor :deleted

        attr_accessor :unchanged

        def print
          added    .sort.each { |pod| UI.message('A'.green  + " #{pod}", '', 2) }
          deleted  .sort.each { |pod| UI.message('R'.red    + " #{pod}", '', 2) }
          changed  .sort.each { |pod| UI.message('M'.yellow + " #{pod}", '', 2) }
          unchanged.sort.each { |pod| UI.message('-'        + " #{pod}", '', 2) }
        end

        def add_name(name, state)
          #nodyna <send-2701> <SD COMPLEX (change-prone variables)>
          send(state) << name
        end
      end
    end
  end
end
