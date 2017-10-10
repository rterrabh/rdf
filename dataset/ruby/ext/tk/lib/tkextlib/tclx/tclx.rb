require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tclx/setup.rb'

TkPackage.require('Tclx')

module Tk
  module TclX
    PACKAGE_NAME = 'Tclx'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('Tclx')
      rescue
        ''
      end
    end

    def self.infox(*args)
      Tk.tk_call('infox', *args)
    end

    def self.signal(*args)
      warn("Warning: Don't recommend to use TclX's 'signal' command. Please use Ruby's 'Signal.trap' method")
      Tk.tk_call('signal', *args)
    end

    def self.signal_restart(*args)
      warn("Warning: Don't recommend to use TclX's 'signal' command. Please use Ruby's 'Signal.trap' method")
      Tk.tk_call('signal', '-restart', *args)
    end


    class XPG3_MsgCat
      class << self
        alias open new
      end

      def initialize(catname, fail_mode=false)
        if fail_mode
          @msgcat_id = Tk.tk_call('catopen', '-fail', catname)
        else
          @msgcat_id = Tk.tk_call('catopen', '-nofail', catname)
        end
      end

      def close(fail_mode=false)
        if fail_mode
          Tk.tk_call('catclose', '-fail', @msgcat_id)
        else
          Tk.tk_call('catclose', '-nofail', @msgcat_id)
        end
        self
      end

      def get(setnum, msgnum, defaultstr)
        Tk.tk_call('catgets', @msgcat_id, setnum, msgnum, defaultstr)
      end
    end
  end
end
