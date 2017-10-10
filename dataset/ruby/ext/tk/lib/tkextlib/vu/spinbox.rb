require 'tk'

if (Tk::TK_MAJOR_VERSION < 8 ||
    (Tk::TK_MAJOR_VERSION == 8 && Tk::TK_MINOR_VERSION < 4))
  require 'tkextlib/vu.rb'

  Tk.tk_call('namespace', 'import', '::vu::spinbox')
end

module Tk
  module Vu
    Spinbox = Tk::Spinbox
  end
end
