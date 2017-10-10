
require 'tk'
require 'tkextlib/tcllib.rb'

unless defined? Tk::Tcllib::Tablelist_usingTile
  Tk::Tcllib::Tablelist_usingTile =
    TkPackage.provide('tile') || TkPackage.provide('Ttk')
end

if Tk::Tcllib::Tablelist_usingTile
  require 'tkextlib/tcllib/tablelist_tile'

else

  TkPackage.require('tablelist')

  require 'tkextlib/tcllib/tablelist_core'
end
