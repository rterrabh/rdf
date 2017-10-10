
require 'tk'
require 'tk/scrollbar'
require 'tkextlib/tcllib.rb'

module Tk
  module Tcllib
    module Autoscroll
      PACKAGE_NAME = 'autoscroll'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('autoscroll')
        rescue
          ''
        end
      end

      def self.not_available
        fail RuntimeError, "'tkextlib/tcllib/autoscroll' extension is not available on your current environment."
      end

      def self.autoscroll(win)
        Tk::Tcllib::Autoscroll.not_available
      end

      def self.unautoscroll(win)
        Tk::Tcllib::Autoscroll.not_available
      end
    end
  end
end

module Tk
  module Scrollable
    def autoscroll(mode = nil)
      case mode
      when :x, 'x'
        if @xscrollbar
          Tk::Tcllib::Autoscroll.autoscroll(@xscrollbar)
        end
      when :y, 'y'
        if @yscrollbar
          Tk::Tcllib::Autoscroll.autoscroll(@yscrollbar)
        end
      when nil, :both, 'both'
        if @xscrollbar
          Tk::Tcllib::Autoscroll.autoscroll(@xscrollbar)
        end
        if @yscrollbar
          Tk::Tcllib::Autoscroll.autoscroll(@yscrollbar)
        end
      else
        fail ArgumentError, "'x', 'y' or 'both' (String or Symbol) is expected"
      end
      self
    end
    def unautoscroll(mode = nil)
      case mode
      when :x, 'x'
        if @xscrollbar
          Tk::Tcllib::Autoscroll.unautoscroll(@xscrollbar)
        end
      when :y, 'y'
        if @yscrollbar
          Tk::Tcllib::Autoscroll.unautoscroll(@yscrollbar)
        end
      when nil, :both, 'both'
        if @xscrollbar
          Tk::Tcllib::Autoscroll.unautoscroll(@xscrollbar)
        end
        if @yscrollbar
          Tk::Tcllib::Autoscroll.unautoscroll(@yscrollbar)
        end
      else
        fail ArgumentError, "'x', 'y' or 'both' (String or Symbol) is expected"
      end
      self
    end
  end
end

class Tk::Scrollbar
  def autoscroll
    Tk::Tcllib::Autoscroll.autoscroll(self)
    self
  end
  def unautoscroll
    Tk::Tcllib::Autoscroll.unautoscroll(self)
    self
  end
end

TkPackage.require('autoscroll')

module Tk
  module Tcllib
    class << Autoscroll
      undef not_available
    end

    module Autoscroll
      extend TkCore
      def self.autoscroll(win)
        tk_call_without_enc('::autoscroll::autoscroll', win.path)
      end

      def self.unautoscroll(win)
        tk_call_without_enc('::autoscroll::unautoscroll', win.path)
      end

      def self.wrap
        tk_call_without_enc('::autoscroll::wrap')
      end

      def self.unwrap
        tk_call_without_enc('::autoscroll::unwrap')
      end
    end
  end
end
