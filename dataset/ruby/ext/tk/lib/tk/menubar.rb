



require 'tk'
require 'tk/frame'
require 'tk/composite'
require 'tk/menuspec'

class TkMenubar<Tk::Frame
  include TkComposite
  include TkMenuSpec

  def initialize(parent = nil, spec = nil, options = {})
    if parent.kind_of? Hash
      options = parent
      parent = nil
      spec = (options.has_key?('spec'))? options.delete('spec'): nil
    end

    _symbolkey2str(options)
    menuspec_opt = {}
    TkMenuSpec::MENUSPEC_OPTKEYS.each{|key|
      menuspec_opt[key] = options.delete(key) if options.has_key?(key)
    }

    super(parent, options)

    @menus = []

    spec.each{|info| add_menu(info, menuspec_opt)} if spec

    options.each{|key, value| configure(key, value)} if options
  end

  def add_menu(menu_info, menuspec_opt={})
    mbtn, menu = _create_menubutton(@frame, menu_info, menuspec_opt)

    submenus = _get_cascade_menus(menu).flatten

    @menus.push([mbtn, menu])
    delegate('tearoff', menu, *submenus)
    delegate('foreground', mbtn, menu, *submenus)
    delegate('background', mbtn, menu, *submenus)
    delegate('disabledforeground', mbtn, menu, *submenus)
    delegate('activeforeground', mbtn, menu, *submenus)
    delegate('activebackground', mbtn, menu, *submenus)
    delegate('font', mbtn, menu, *submenus)
    delegate('kanjifont', mbtn, menu, *submenus)
  end

  def [](index)
    return @menus[index]
  end
end
