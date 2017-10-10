module Tk
  autoload :Grid,             'tk/grid'
  def Grid(*args); TkGrid.configure(*args); end

  autoload :Pack,             'tk/pack'
  def Pack(*args); TkPack.configure(*args); end

  autoload :Place,            'tk/place'
  def Place(*args); TkPlace.configure(*args); end
end

autoload :TkGrid,             'tk/grid'
def TkGrid(*args); TkGrid.configure(*args); end

autoload :TkPack,             'tk/pack'
def TkPack(*args); TkPack.configure(*args); end

autoload :TkPlace,            'tk/place'
def TkPlace(*args); TkPlace.configure(*args); end


module Tk
  autoload :Busy,             'tk/busy'

  autoload :Button,           'tk/button'

  autoload :Canvas,           'tk/canvas'

  autoload :CheckButton,      'tk/checkbutton'
  autoload :Checkbutton,      'tk/checkbutton'

  autoload :Entry,            'tk/entry'

  autoload :Frame,            'tk/frame'

  autoload :Label,            'tk/label'

  autoload :LabelFrame,       'tk/labelframe'
  autoload :Labelframe,       'tk/labelframe'

  autoload :Listbox,          'tk/listbox'

  autoload :Menu,             'tk/menu'
  autoload :MenuClone,        'tk/menu'
  autoload :CloneMenu,        'tk/menu'
  autoload :SystemMenu,       'tk/menu'
  autoload :SysMenu_Help,     'tk/menu'
  autoload :SysMenu_System,   'tk/menu'
  autoload :SysMenu_Apple,    'tk/menu'
  autoload :Menubutton,       'tk/menu'
  autoload :MenuButton,       'tk/menu'
  autoload :OptionMenubutton, 'tk/menu'
  autoload :OptionMenBbutton, 'tk/menu'

  autoload :Message,          'tk/message'

  autoload :PanedWindow,      'tk/panedwindow'
  autoload :Panedwindow,      'tk/panedwindow'

  autoload :RadioButton,      'tk/radiobutton'
  autoload :Radiobutton,      'tk/radiobutton'

  autoload :Root,             'tk/root'

  autoload :Scale,            'tk/scale'

  autoload :Scrollbar,        'tk/scrollbar'
  autoload :XScrollbar,       'tk/scrollbar'
  autoload :YScrollbar,       'tk/scrollbar'

  autoload :Spinbox,          'tk/spinbox'

  autoload :Text,             'tk/text'

  autoload :Toplevel,         'tk/toplevel'
end


module Tk
  autoload :Clock,            'tk/clock'

  autoload :OptionObj,        'tk/optionobj'

  autoload :X_Scrollable,     'tk/scrollable'
  autoload :Y_Scrollable,     'tk/scrollable'
  autoload :Scrollable,       'tk/scrollable'

  autoload :Fontchooser,      'tk/fontchooser'

  autoload :Wm,               'tk/wm'
  autoload :Wm_for_General,   'tk/wm'

  autoload :MacResource,      'tk/macpkg'

  autoload :WinDDE,           'tk/winpkg'
  autoload :WinRegistry,      'tk/winpkg'

  autoload :ValidateConfigure,     'tk/validation'
  autoload :ItemValidateConfigure, 'tk/validation'

  autoload :EncodedString,    'tk/encodedstr'
  def Tk.EncodedString(str, enc = nil); Tk::EncodedString.new(str, enc); end

  autoload :BinaryString,     'tk/encodedstr'
  def Tk.BinaryString(str); Tk::BinaryString.new(str); end

  autoload :UTF8_String,      'tk/encodedstr'
  def Tk.UTF8_String(str); Tk::UTF8_String.new(str); end

end


autoload :TkBgError,          'tk/bgerror'

autoload :TkBindTag,          'tk/bindtag'
autoload :TkBindTagAll,       'tk/bindtag'
autoload :TkDatabaseClass,    'tk/bindtag'

autoload :TkConsole,          'tk/console'

autoload :TkcItem,            'tk/canvas'
autoload :TkcArc,             'tk/canvas'
autoload :TkcBitmap,          'tk/canvas'
autoload :TkcImage,           'tk/canvas'
autoload :TkcLine,            'tk/canvas'
autoload :TkcOval,            'tk/canvas'
autoload :TkcPolygon,         'tk/canvas'
autoload :TkcRectangle,       'tk/canvas'
autoload :TkcText,            'tk/canvas'
autoload :TkcWindow,          'tk/canvas'

autoload :TkcTagAccess,       'tk/canvastag'
autoload :TkcTag,             'tk/canvastag'
autoload :TkcTagString,       'tk/canvastag'
autoload :TkcNamedTag,        'tk/canvastag'
autoload :TkcTagAll,          'tk/canvastag'
autoload :TkcTagCurrent,      'tk/canvastag'
autoload :TkcTagGroup,        'tk/canvastag'

autoload :TkClipboard,        'tk/clipboard'

autoload :TkComposite,        'tk/composite'

autoload :TkConsole,          'tk/console'

autoload :TkDialog,           'tk/dialog'
autoload :TkDialog2,          'tk/dialog'
autoload :TkDialogObj,        'tk/dialog'
autoload :TkWarning,          'tk/dialog'
autoload :TkWarning2,         'tk/dialog'
autoload :TkWarningObj,       'tk/dialog'

autoload :TkEvent,            'tk/event'

autoload :TkFont,             'tk/font'
autoload :TkNamedFont,        'tk/font'

autoload :TkImage,            'tk/image'
autoload :TkBitmapImage,      'tk/image'
autoload :TkPhotoImage,       'tk/image'

autoload :TkItemConfigMethod, 'tk/itemconfig'

autoload :TkTreatItemFont,    'tk/itemfont'

autoload :TkKinput,           'tk/kinput'

autoload :TkSystemMenu,       'tk/menu'

autoload :TkMenubar,          'tk/menubar'

autoload :TkMenuSpec,         'tk/menuspec'

autoload :TkManageFocus,      'tk/mngfocus'

autoload :TkMsgCatalog,       'tk/msgcat'
autoload :TkMsgCat,           'tk/msgcat'

autoload :TkNamespace,        'tk/namespace'

autoload :TkOptionDB,         'tk/optiondb'
autoload :TkOption,           'tk/optiondb'
autoload :TkResourceDB,       'tk/optiondb'

autoload :TkPackage,          'tk/package'

autoload :TkPalette,          'tk/palette'

autoload :TkRoot,             'tk/root'

autoload :TkScrollbox,        'tk/scrollbox'

autoload :TkSelection,        'tk/selection'

autoload :TkTreatTagFont,     'tk/tagfont'

autoload :TkTextImage,        'tk/textimage'
autoload :TktImage,           'tk/textimage'

autoload :TkTextMark,         'tk/textmark'
autoload :TkTextNamedMark,    'tk/textmark'
autoload :TkTextMarkInsert,   'tk/textmark'
autoload :TkTextMarkCurrent,  'tk/textmark'
autoload :TkTextMarkAnchor,   'tk/textmark'
autoload :TktMark,            'tk/textmark'
autoload :TktNamedMark,       'tk/textmark'
autoload :TktMarkInsert,      'tk/textmark'
autoload :TktMarkCurrent,     'tk/textmark'
autoload :TktMarkAnchor,      'tk/textmark'

autoload :TkTextTag,          'tk/texttag'
autoload :TkTextNamedTag,     'tk/texttag'
autoload :TkTextTagSel,       'tk/texttag'
autoload :TktTag,             'tk/texttag'
autoload :TktNamedTag,        'tk/texttag'
autoload :TktTagSel,          'tk/texttag'

autoload :TkTextWindow,       'tk/textwindow'
autoload :TktWindow,          'tk/textwindow'

autoload :TkAfter,            'tk/timer'
autoload :TkTimer,            'tk/timer'
autoload :TkRTTimer,          'tk/timer'

autoload :TkTextWin,          'tk/txtwin_abst'

autoload :TkValidation,       'tk/validation'
autoload :TkValidateCommand,  'tk/validation'

autoload :TkVariable,         'tk/variable'
autoload :TkVarAccess,        'tk/variable'

autoload :TkVirtualEvent,     'tk/virtevent'
autoload :TkNamedVirtualEvent,'tk/virtevent'

autoload :TkWinfo,            'tk/winfo'

autoload :TkXIM,              'tk/xim'


module Tk
  @TOPLEVEL_ALIAS_TABLE = {}
  @TOPLEVEL_ALIAS_TABLE[:Tk] = {
    :TkButton             => 'tk/button',

    :TkCanvas             => 'tk/canvas',

    :TkCheckButton        => 'tk/checkbutton',
    :TkCheckbutton        => 'tk/checkbutton',


    :TkEntry              => 'tk/entry',

    :TkFrame              => 'tk/frame',

    :TkLabel              => 'tk/label',

    :TkLabelFrame         => 'tk/labelframe',
    :TkLabelframe         => 'tk/labelframe',

    :TkListbox            => 'tk/listbox',

    :TkMacResource        => 'tk/macpkg',

    :TkMenu               => 'tk/menu',
    :TkMenuClone          => 'tk/menu',
    :TkCloneMenu          => 'tk/menu',
    :TkSysMenu_Help       => 'tk/menu',
    :TkSysMenu_System     => 'tk/menu',
    :TkSysMenu_Apple      => 'tk/menu',
    :TkMenubutton         => 'tk/menu',
    :TkMenuButton         => 'tk/menu',
    :TkOptionMenubutton   => 'tk/menu',
    :TkOptionMenuButton   => 'tk/menu',

    :TkMessage            => 'tk/message',

    :TkPanedWindow        => 'tk/panedwindow',
    :TkPanedwindow        => 'tk/panedwindow',

    :TkRadioButton        => 'tk/radiobutton',
    :TkRadiobutton        => 'tk/radiobutton',


    :TkScale              => 'tk/scale',

    :TkScrollbar          => 'tk/scrollbar',
    :TkXScrollbar         => 'tk/scrollbar',
    :TkYScrollbar         => 'tk/scrollbar',

    :TkSpinbox            => 'tk/spinbox',

    :TkText               => 'tk/text',

    :TkToplevel           => 'tk/toplevel',

    :TkWinDDE             => 'tk/winpkg',
    :TkWinRegistry        => 'tk/winpkg',
  }

  @TOPLEVEL_ALIAS_OWNER = {}

  @TOPLEVEL_ALIAS_SETUP_PROC = {}

  @AUTOLOAD_FILE_SYM_TABLE = Hash.new{|h,k| h[k]={}} # TABLE[file][sym] -> obj

  @current_default_widget_set = nil

  module TOPLEVEL_ALIASES; end
end

class Object
  include Tk::TOPLEVEL_ALIASES
end


class << Tk
  def default_widget_set
    @current_default_widget_set
  end

  def default_widget_set=(target)
    target = target.to_sym
    return target if target == @current_default_widget_set

    if (cmd = @TOPLEVEL_ALIAS_SETUP_PROC[target])
      cmd.call(target)
    end

    _replace_toplevel_aliases(target)
  end

  def widget_set_symbols
    @TOPLEVEL_ALIAS_TABLE.keys
  end

  def toplevel_aliases_on_widget_set(widget_set)
    if (tbl = @TOPLEVEL_ALIAS_TABLE[widget_set.to_sym])
      tbl.collect{|k, v| (v.nil?)? nil: k}.compact
    else
      fail ArgumentError, "unknown widget_set #{widget_set.to_sym.inspect}"
    end
  end

  def __toplevel_alias_setup_proc__(*target_list, &cmd)
    target_list.each{|target| @TOPLEVEL_ALIAS_SETUP_PROC[target.to_sym] = cmd}
  end

  def topobj_defined?(sym) #=> alias_filename or object or false
    Object.autoload?(sym) ||
      #nodyna <const_get-1859> <CG COMPLEX (change-prone variable)>
      (Object.const_defined?(sym) && Object.const_get(sym))
  end
  def topalias_defined?(sym) #=> alias_filename or object or false
    Tk::TOPLEVEL_ALIASES.autoload?(sym) ||
      (Tk::TOPLEVEL_ALIASES.const_defined?(sym) &&
         #nodyna <const_get-1860> <CG COMPLEX (change-prone variable)>
         Tk::TOPLEVEL_ALIASES.const_get(sym))
  end
  def define_topobj(sym, obj)
    if obj.kind_of? String
      Object.autoload(sym, obj)
      unless Object.autoload?(sym)
        if @AUTOLOAD_FILE_SYM_TABLE.has_key?(obj) &&
            (loaded_obj = @AUTOLOAD_FILE_SYM_TABLE[obj][sym])
          #nodyna <const_set-1861> <CS COMPLEX (change-prone variable)>
          Object.const_set(sym, loaded_obj)
        else
          fail ArgumentError, "cannot define autoload file (already loaded?)"
        end
      end
    else
      #nodyna <const_set-1862> <CS COMPLEX (change-prone variable)>
      Object.const_set(sym, obj)
    end
  end
  def define_topalias(sym, obj)
    if obj.kind_of? String
      Tk::TOPLEVEL_ALIASES.autoload(sym, obj)
      unless Tk::TOPLEVEL_ALIASES.autoload?(sym)
        if @AUTOLOAD_FILE_SYM_TABLE.has_key?(obj) &&
            (loaded_obj = @AUTOLOAD_FILE_SYM_TABLE[obj][sym])
          #nodyna <const_set-1863> <CS COMPLEX (change-prone variable)>
          Tk::TOPLEVEL_ALIASES.const_set(sym, loaded_obj)
        else
          fail ArgumentError, "cannot define autoload file (already loaded?)"
        end
      end
    else
      #nodyna <const_set-1864> <CS COMPLEX (change-prone variable)>
      Tk::TOPLEVEL_ALIASES.const_set(sym, obj)
    end
  end
  def replace_topobj(sym, obj) #=> old_obj (alias_filename or object) or nil
    if old_obj = topobj_defined?(sym)
      #nodyna <class_eval-1865> <not yet classified>
      Object.class_eval{remove_const sym} rescue nil # ignore err
    end
    define_topobj(sym, obj)
    old_obj
  end
  def replace_topalias(sym, obj) #=> old_obj (alias_filename or object) or nil
    if old_obj = topalias_defined?(sym)
      #nodyna <module_eval-1866> <not yet classified>
      Tk::TOPLEVEL_ALIASES.module_eval{remove_const sym} rescue nil #ignore err
    end
    define_topalias(sym, obj)
    old_obj
  end
  private :topobj_defined?, :topalias_defined?
  private :define_topobj, :define_topalias
  private :replace_topobj, :replace_topalias

  def __regist_toplevel_aliases__(target, obj, *symbols)
    @TOPLEVEL_ALIAS_TABLE[target = target.to_sym] ||= {}
    symbols.each{|sym|
      @TOPLEVEL_ALIAS_TABLE[target][sym = sym.to_sym] = obj
      if !topalias_defined?(sym) || target == @current_default_widget_set
        @TOPLEVEL_ALIAS_OWNER[sym] = target
        replace_topalias(sym, obj)
        replace_topobj(sym, obj) unless obj.kind_of?(String) # NOT autoload
      end
    }
  end

  def regist_sym_for_loaded_file(auto, obj, sym)
    @AUTOLOAD_FILE_SYM_TABLE[auto][sym] = obj

    reg = /^#{Regexp.quote(auto)}(\.rb|\.so|)$/
    @TOPLEVEL_ALIAS_TABLE.each_key{|set|
      if @TOPLEVEL_ALIAS_TABLE[set][sym] =~ reg
        @TOPLEVEL_ALIAS_TABLE[set][sym] = obj
        if @TOPLEVEL_ALIAS_OWNER[sym].nil? || @TOPLEVEL_ALIAS_OWNER[sym] == set
          replace_topalias(sym, obj)
          replace_topobj(sym, obj) if set == @current_default_widget_set
        end
      end
    }
    if (f = Object.autoload?(sym)) && f =~ reg
      replace_topobj(sym, obj)
    end
    if (f = Tk::TOPLEVEL_ALIASES.autoload?(sym)) && f =~ reg
      replace_topalias(sym, obj)
    end
  end
  private :regist_sym_for_loaded_file

  def set_topalias(target, obj, sym)
    if target == @current_default_widget_set
      case @TOPLEVEL_ALIAS_OWNER[sym]
      when false
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
        replace_topalias(sym, obj)

      when target
        if current_obj = topobj_defined?(sym)
          if current_obj == obj
            @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
            replace_topalias(sym, obj)

          else # current_obj != obj
            if current_obj == topalias_defined?(sym)
              @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
              replace_topalias(sym, obj)
              replace_topobj(sym, obj)

            else # current_obj != topalias_defined?(sym)
              @TOPLEVEL_ALIAS_OWNER[sym] = false
              @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
              replace_topalias(sym, obj)
            end
          end

        else # NOT topobj_defined?(sym)
          @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
          replace_topalias(sym, obj)
          define_topobj(sym, obj)
        end

      when nil
        @TOPLEVEL_ALIAS_OWNER[sym] = target
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
        replace_topalias(sym, obj)

      else # others
        @TOPLEVEL_ALIAS_OWNER[sym] = target
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
        replace_topalias(sym, obj)
        replace_topobj(sym, obj)
      end

    else # target != @current_default_widget_set
      case @TOPLEVEL_ALIAS_OWNER[sym]
      when false
        if topalias_defined?(sym)
          @TOPLEVEL_ALIAS_TABLE[target][sym] = obj

        else # NOT topalias_defined?(sym)
          @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
          define_topalias(sym, obj)
        end

      when target
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
        replace_topalias(sym, obj)
        replace_topobj(sym, obj)

      when nil
        @TOPLEVEL_ALIAS_OWNER[sym] = target
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj
        replace_topalias(sym, obj)
        replace_topobj(sym, obj)

      else # others
        @TOPLEVEL_ALIAS_TABLE[target][sym] = obj

      end
    end

    sym
  end
  private :set_topalias

  def __set_toplevel_aliases__(target, obj, *symbols)
    target = target.to_sym
    symbols.each{|sym| set_topalias(target, obj, sym.to_sym)}
  end

  def __set_loaded_toplevel_aliases__(autopath, target, obj, *symbols)
    shortpath = (autopath =~ /^(.*)(.rb|.so)$/)? $1: autopath
    target = target.to_sym
    symbols.map!{|sym| sym.to_sym}

    symbols.each{|sym| regist_sym_for_loaded_file(shortpath, obj, sym) }
    symbols.each{|sym| set_topalias(target, obj, sym)}
  end

  def backup_current_topdef(sym)
    return if (current = @current_default_widget_set).nil?

    case @TOPLEVEL_ALIAS_OWNER[sym]
    when false
      if (cur_alias = topalias_defined?(sym)) && ! cur_alias.kind_of?(String)
        @TOPLEVEL_ALIAS_TABLE[current][sym] = cur_alias
      end

    when current
      if cur_obj = topobj_defined?(sym)
        if ! cur_obj.kind_of?(String) && (cur_alias = topalias_defined?(sym))
          if cur_alias.kind_of?(String)
            @TOPLEVEL_ALIAS_OWNER[sym] = false
          elsif cur_obj == cur_alias
            @TOPLEVEL_ALIAS_TABLE[current][sym] = cur_alias
          else
            @TOPLEVEL_ALIAS_OWNER[sym] = false
          end
        end
      else
        @TOPLEVEL_ALIAS_OWNER[sym] = false
      end

    when nil
      if (cur_alias = topalias_defined?(sym)) && ! cur_alias.kind_of?(String)
        @TOPLEVEL_ALIAS_TABLE[current][sym] = cur_alias
      end
    else
    end
  end
  private :backup_current_topdef

  def _replace_toplevel_aliases(target)
    @TOPLEVEL_ALIAS_TABLE[target].each_key{|sym|
      backup_current_topdef(sym)
    }

    @TOPLEVEL_ALIAS_TABLE[target].each_key{|sym|
      next if (obj = @TOPLEVEL_ALIAS_TABLE[target][sym]).nil?
      if @TOPLEVEL_ALIAS_OWNER[sym] == false
        replace_topalias(sym, obj)
      else
        @TOPLEVEL_ALIAS_OWNER[sym] = target
        replace_topalias(sym, obj)
        replace_topobj(sym, obj)
      end
    }

    @current_default_widget_set = target
  end
  private :_replace_toplevel_aliases

  def __import_toplevel_aliases__(target, *symbols)
    current = @current_default_widget_set
    symbols.each{|sym|
      sym = sym.to_sym
      if (obj = @TOPLEVEL_ALIAS_TABLE[target][sym]).nil?
        @TOPLEVEL_ALIAS_TABLE[current].delete(sym)
        @TOPLEVEL_ALIAS_OWNER.delete(sym)
        #nodyna <module_eval-1867> <not yet classified>
        Tk::TOPLEVEL_ALIASES.module_eval{remove_const sym} if topalias_defined?(sym)
        #nodyna <class_eval-1868> <not yet classified>
        Object.class_eval{remove_const sym} if topobj_defined?(sym)

      elsif obj == false
        @TOPLEVEL_ALIAS_TABLE[current].delete(sym)
        @TOPLEVEL_ALIAS_OWNER[sym] = false
        #nodyna <module_eval-1869> <not yet classified>
        Tk::TOPLEVEL_ALIASES.module_eval{remove_const sym} if topalias_defined?(sym)

      elsif @TOPLEVEL_ALIAS_OWNER[sym] == false
        @TOPLEVEL_ALIAS_TABLE[current][sym] = obj
        replace_topalias(sym, obj)

      else
        @TOPLEVEL_ALIAS_OWNER[sym] = current
        @TOPLEVEL_ALIAS_TABLE[current][sym] = obj
        replace_topalias(sym, obj)
        replace_topobj(sym, obj)
      end
    }
  end

  def __remove_toplevel_aliases__(*symbols)
    current = @current_default_widget_set
    symbols.each{|sym|
      sym = sym.to_sym
      @TOPLEVEL_ALIAS_TABLE[current].delete(sym)
      @TOPLEVEL_ALIAS_OWNER.delete(sym)
      #nodyna <module_eval-1870> <not yet classified>
      Tk::TOPLEVEL_ALIASES.module_eval{remove_const sym} if topalias_defined?(sym)
      #nodyna <class_eval-1871> <not yet classified>
      Object.class_eval{remove_const sym} if topobj_defined?(sym)
    }
  end

  def __reset_toplevel_owner__(*symbols)
    symbols.each{|sym| @TOPLEVEL_ALIAS_OWNER.delete(sym.to_sym)}
  end

  def __disable_toplevel_control__(*symbols)
    symbols.each{|sym| @TOPLEVEL_ALIAS_OWNER[sym.to_sym] = false}
  end

  def __create_widget_set__(new_set, src_set={})
    new_set = new_set.to_sym
    if @TOPLEVEL_ALIAS_TABLE[new_set]
      fail RuntimeError, "A widget-set #{new_set.inspect} is already exist."
    end
    if src_set.kind_of?(Symbol)
      @TOPLEVEL_ALIAS_TABLE[new_set] = @TOPLEVEL_ALIAS_TABLE[src_set]
    else
      @TOPLEVEL_ALIAS_TABLE[new_set] = {}
      src_set.each{|sym, obj| set_topalias(new_set, obj, sym.to_sym) }
    end
  end
end


Tk.default_widget_set = :Tk



=begin
if major > 8 ||
    (major == 8 && minor > 5) ||
    (major == 8 && minor == 5 && type >= TclTkLib::RELEASE_TYPE::BETA)
  Object.autoload :Ttk, 'tkextlib/tile'
  Tk.autoload :Tile, 'tkextlib/tile'

  require 'tk/ttk_selector'
end
=end
Object.autoload :Ttk, 'tkextlib/tile'
Tk.autoload :Tile, 'tkextlib/tile'
require 'tk/ttk_selector'
