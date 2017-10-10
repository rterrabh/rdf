require 'tk'
require 'tk/wm'
require 'tk/menuspec'

class Tk::Root<TkWindow
  include Wm
  include TkMenuSpec

  def __methodcall_optkeys  # { key=>method, ... }
    TOPLEVEL_METHODCALL_OPTKEYS
  end
  private :__methodcall_optkeys

  def Root.new(keys=nil, &b)
    unless TkCore::INTERP.tk_windows['.']
      TkCore::INTERP.tk_windows['.'] =
        super(:without_creating=>true, :widgetname=>'.'){}
    end
    root = TkCore::INTERP.tk_windows['.']

    keys = _symbolkey2str(keys)

    #nodyna <instance_eval-1890> <IEV COMPLEX (private access)>
    root.instance_eval{
      __methodcall_optkeys.each{|key, method|
        value = keys.delete(key.to_s)
        self.__send__(method, value) if value
      }
    }

    if keys  # wm commands ( for backward comaptibility )
      keys.each{|k,v|
        if v.kind_of? Array
          root.__send__(k,*v)
        else
          root.__send__(k,v)
        end
      }
    end

    if block_given?
      if TkCore::WITH_RUBY_VM  ### Ruby 1.9 !!!!
        #nodyna <instance_exec-1891> <IEX COMPLEX (block with parameters)>
        root.instance_exec(root, &b)
      else
        #nodyna <instance_eval-1892> <IEV COMPLEX (block execution)>
        root.instance_eval(&b)
      end
    end
    root
  end

  WidgetClassName = 'Tk'.freeze
  WidgetClassNames[WidgetClassName] ||= self

  def self.to_eval
    '.'
  end

  def create_self
    @path = '.'
  end
  private :create_self

  def path
    "."
  end

  def add_menu(menu_info, tearoff=false, opts=nil)
    if tearoff.kind_of?(Hash)
      opts = tearoff
      tearoff = false
    end
    _create_menubutton(self, menu_info, tearoff, opts)
  end

  def add_menubar(menu_spec, tearoff=false, opts=nil)
    menu_spec.each{|info| add_menu(info, tearoff, opts)}
    self.menu
  end

  def Root.destroy
    TkCore::INTERP._invoke('destroy', '.')
  end
end

TkRoot = Tk::Root unless Object.const_defined? :TkRoot
