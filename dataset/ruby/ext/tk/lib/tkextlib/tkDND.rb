require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tkDND/setup.rb'

module Tk
  module TkDND
    autoload :DND,   'tkextlib/tkDND/tkdnd'
    autoload :Shape, 'tkextlib/tkDND/shape'
  end
end
