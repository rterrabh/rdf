module ActiveAdmin

  # Shareable module to give a #display_on?(action) method
  # which returns true or false depending on an options hash.
  #
  # The options hash accepts:
  #
  # only: :index
  # only: [:index, :show]
  # except: :index
  # except: [:index, :show]
  #
  # call #normalize_display_options! after @options has been set
  # to ensure that the display options are setup correctly

  module OptionalDisplay
    def display_on?(action, render_context = self)
      return false if @options[:only]   && !@options[:only].include?(action.to_sym)
      return false if @options[:except] && @options[:except].include?(action.to_sym)

      case condition = @options[:if]
      when Symbol, String
        #nodyna <ID:send-52> <send VERY HIGH ex3>
        render_context.public_send condition
      when Proc
        #nodyna <ID:instance_exec-16> <instance_exec VERY HIGH ex1>
        render_context.instance_exec &condition
      else
        true
      end
    end

    private

    def normalize_display_options!
      @options[:only]   = Array(@options[:only])   if @options[:only]
      @options[:except] = Array(@options[:except]) if @options[:except]
    end
  end
end