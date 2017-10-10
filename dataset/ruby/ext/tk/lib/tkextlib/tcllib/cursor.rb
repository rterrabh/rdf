
require 'tk'
require 'tkextlib/tcllib.rb'

module Tk
  module Tcllib
    module Cursor
      PACKAGE_NAME = 'cursor'.freeze
      def self.package_name
        PACKAGE_NAME
      end

      def self.package_version
        begin
          TkPackage.require('cursor')
        rescue
          ''
        end
      end

      def self.not_available
        fail RuntimeError, "'tkextlib/tcllib/cursor' extension is not available on your current environment."
      end

      def self.cursor_display(win=None)
        Tk::Tcllib::Cursor.not_available
      end

      def self.cursor_propagate(win, cursor)
        Tk::Tcllib::Cursor.not_available
      end

      def self.cursor_restore(win, cursor = None)
        Tk::Tcllib::Cursor.not_available
      end
    end
  end

  def self.cursor_display(parent=None)
    Tk::Tcllib::Cursor.cursor_display(parent)
  end
end

class TkWindow
  def cursor_propagate(cursor)
    Tk::Tcllib::Cursor.cursor_propagate(self, cursor)
  end
  def cursor_restore(cursor = None)
    Tk::Tcllib::Cursor.cursor_restore(self, cursor)
  end
end

TkPackage.require('cursor')

module Tk
  module Tcllib
    class << Cursor
      undef not_available
    end

    module Cursor
      extend TkCore
      def self.cursor_display(win=None)
        tk_call_without_enc('::cursor::display', _epath(win))
      end

      def self.cursor_propagate(win, cursor)
        tk_call_without_enc('::cursor::propagate', _epath(win), cursor)
      end

      def self.cursor_restore(win, cursor = None)
        tk_call_without_enc('::cursor::restore', _epath(win), cursor)
      end
    end
  end
end
