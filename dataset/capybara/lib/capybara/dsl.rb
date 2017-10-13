require 'capybara'

module Capybara
  module DSL
    def self.included(base)
      warn "including Capybara::DSL in the global scope is not recommended!" if base == Object
      super
    end

    def self.extended(base)
      #nodyna <eval-2627> <EV COMPLEX (scope)>
      warn "extending the main object with Capybara::DSL is not recommended!" if base == TOPLEVEL_BINDING.eval("self")
      super
    end

    def using_session(name, &block)
      Capybara.using_session(name, &block)
    end

    def using_wait_time(seconds, &block)
      Capybara.using_wait_time(seconds, &block)
    end

    def page
      Capybara.current_session
    end

    Session::DSL_METHODS.each do |method|
      #nodyna <define_method-2628> <DM MODERATE (array)>
      define_method method do |*args, &block|
        #nodyna <send-2629> <SD MODERATE (array)>
        page.send method, *args, &block
      end
    end
  end

  extend(Capybara::DSL)
end
