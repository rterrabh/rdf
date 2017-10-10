module ActiveAdmin


  module OptionalDisplay
    def display_on?(action, render_context = self)
      return false if @options[:only]   && !@options[:only].include?(action.to_sym)
      return false if @options[:except] && @options[:except].include?(action.to_sym)

      case condition = @options[:if]
      when Symbol, String
        #nodyna <send-91> <SD COMPLEX (change-prone variables)>
        render_context.public_send condition
      when Proc
        #nodyna <instance_exec-92> <IEX COMPLEX (block without parameters)>
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
