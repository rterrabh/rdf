
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/tcllib/setup.rb'

err = ''

target = 'tkextlib/tcllib/autoscroll'
begin
  require target
rescue => e
  err << "\n  ['" << target << "'] "  << e.class.name << ' : ' << e.message
end

target = 'tkextlib/tcllib/cursor'
begin
  require target
rescue => e
  err << "\n  ['" << target << "'] "  << e.class.name << ' : ' << e.message
end

target = 'tkextlib/tcllib/style'
begin
  require target
rescue => e
  err << "\n  ['" << target << "'] "  << e.class.name << ' : ' << e.message
end

module Tk
  module Tcllib
    TkComm::TkExtlibAutoloadModule.unshift(self)

    autoload :Autoscroll,         'tkextlib/tcllib/autoscroll'

    autoload :CText,              'tkextlib/tcllib/ctext'

    autoload :Cursor,             'tkextlib/tcllib/cursor'

    autoload :Datefield,          'tkextlib/tcllib/datefield'
    autoload :DateField,          'tkextlib/tcllib/datefield'

    autoload :GetString_Dialog,   'tkextlib/tcllib/getstring'

    autoload :History,            'tkextlib/tcllib/history'

    autoload :ICO,                'tkextlib/tcllib/ico'

    autoload :IP_Entry,           'tkextlib/tcllib/ip_entry'
    autoload :IPEntry,            'tkextlib/tcllib/ip_entry'

    autoload :KHIM,               'tkextlib/tcllib/khim'

    autoload :Ntext,              'tkextlib/tcllib/ntext'

    autoload :Plotchart,          'tkextlib/tcllib/plotchart'

    autoload :Style,              'tkextlib/tcllib/style'

    autoload :Swaplist_Dialog,    'tkextlib/tcllib/swaplist'

    autoload :Tablelist,           'tkextlib/tcllib/tablelist'
    autoload :TableList,           'tkextlib/tcllib/tablelist'
    autoload :Tablelist_Tile,      'tkextlib/tcllib/tablelist_tile'
    autoload :TableList_Tile,      'tkextlib/tcllib/tablelist_tile'

    autoload :Tkpiechart,         'tkextlib/tcllib/tkpiechart'

    autoload :Tooltip,            'tkextlib/tcllib/tooltip'

    autoload :Widget,             'tkextlib/tcllib/widget'
  end
end

if $VERBOSE && !err.empty?
  warn("Warning: some sub-packages are failed to require : " + err)
end
