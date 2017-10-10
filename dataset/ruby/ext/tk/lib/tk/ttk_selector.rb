module Tk
  @TOPLEVEL_ALIAS_TABLE[:Ttk] = {
    :TkButton       => 'tkextlib/tile/tbutton',

    :TkCheckbutton  => 'tkextlib/tile/tcheckbutton',
    :TkCheckButton  => 'tkextlib/tile/tcheckbutton',


    :TkEntry        => 'tkextlib/tile/tentry',

    :TkCombobox     => 'tkextlib/tile/tcombobox',

    :TkFrame        => 'tkextlib/tile/tframe',

    :TkLabel        => 'tkextlib/tile/tlabel',

    :TkLabelframe   => 'tkextlib/tile/tlabelframe',
    :TkLabelFrame   => 'tkextlib/tile/tlabelframe',

    :TkMenubutton   => 'tkextlib/tile/tmenubutton',
    :TkMenuButton   => 'tkextlib/tile/tmenubutton',

    :TkNotebook     => 'tkextlib/tile/tnotebook',

    :TkPanedwindow  => 'tkextlib/tile/tpaned',
    :TkPanedWindow  => 'tkextlib/tile/tpaned',

    :TkProgressbar  => 'tkextlib/tile/tprogressbar',

    :TkRadiobutton  => 'tkextlib/tile/tradiobutton',
    :TkRadioButton  => 'tkextlib/tile/tradiobutton',

    :TkScale        => 'tkextlib/tile/tscale',

    :TkScrollbar    => 'tkextlib/tile/tscrollbar',
    :TkXScrollbar   => 'tkextlib/tile/tscrollbar',
    :TkYScrollbar   => 'tkextlib/tile/tscrollbar',

    :TkSeparator    => 'tkextlib/tile/tseparator',

    :TkSizeGrip     => 'tkextlib/tile/sizegrip',
    :TkSizegrip     => 'tkextlib/tile/sizegrip',


    :TkTreeview     => 'tkextlib/tile/treeview',
  }

  Tk.__create_widget_set__(:Tile, :Ttk)

  major, minor, type, patchlevel = TclTkLib.get_version

  if ([major,minor,type,patchlevel] <=>
        [8,6,TclTkLib::RELEASE_TYPE::BETA,1]) >= 0
    @TOPLEVEL_ALIAS_TABLE[:Ttk].update(
      :TkSpinbox => 'tkextlib/tile/tspinbox'
    )
  end

  @TOPLEVEL_ALIAS_TABLE[:Ttk].each{|sym, file|
    Tk.__regist_toplevel_aliases__(:Ttk, file, sym)
  }


  Tk.__toplevel_alias_setup_proc__(:Ttk, :Tile){|mod|
    unless Tk.autoload?(:Tile) || Tk.const_defined?(:Tile)
      Object.autoload :Ttk, 'tkextlib/tile'
      Tk.autoload :Tile, 'tkextlib/tile'
    end
  }
end
