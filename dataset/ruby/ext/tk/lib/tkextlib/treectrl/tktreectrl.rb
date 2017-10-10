
require 'tk'

require 'tkextlib/setup.rb'

require 'tkextlib/treectrl/setup.rb'

TkPackage.require('treectrl')

module Tk
  class TreeCtrl < TkWindow
    BindTag_FileList = TkBindTag.new_by_name('TreeCtrlFileList')

    PACKAGE_NAME = 'treectrl'.freeze
    def self.package_name
      PACKAGE_NAME
    end

    def self.package_version
      begin
        TkPackage.require('treectrl')
      rescue
        ''
      end
    end

    HasColumnCreateCommand =
      (TkPackage.vcompare(self.package_version, '1.1') >= 0)

    begin
      tk_call('treectrl')
    rescue
    end
    def self.loupe(img, x, y, w, h, zoom)

      Tk.tk_call_without_enc('loupe', img, x, y, w, h, zoom)
    end

    def self.text_layout(font, text, keys={})
      TkComm.list(Tk.tk_call_without_enc('textlayout', font, text, keys))
    end

    def self.image_tint(img, color, alpha)
      Tk.tk_call_without_enc('imagetint', img, color, alpha)
    end

    class NotifyEvent < TkUtil::CallbackSubst
    end

    module ConfigMethod
    end
  end
  TreeCtrl_Widget = TreeCtrl
end


class Tk::TreeCtrl::NotifyEvent
  KEY_TBL = [
    [ ?c, ?n, :item_num ],
    [ ?d, ?s, :detail ],
    [ ?D, ?l, :items ],
    [ ?e, ?e, :event ],
    [ ?I, ?n, :id ],
    [ ?l, ?n, :lower_bound ],
    [ ?p, ?n, :active_id ],
    [ ?P, ?e, :pattern ],
    [ ?S, ?l, :sel_items ],
    [ ?T, ?w, :widget ],
    [ ?u, ?n, :upper_bound ],
    [ ?W, ?o, :object ],
    [ ??, ?x, :parm_info ],
    nil
  ]

  PROC_TBL = [
    [ ?n, TkComm.method(:num_or_str) ],
    [ ?s, TkComm.method(:string) ],
    [ ?l, TkComm.method(:list) ],
    [ ?w, TkComm.method(:window) ],

    [ ?e, proc{|val|
        case val
        when /^<<[^<>]+>>$/
          TkVirtualEvent.getobj(val[1..-2])
        when /^<[^<>]+>$/
          val[1..-2]
        else
          val
        end
      }
    ],

    [ ?o, proc{|val| TkComm.tk_tcl2ruby(val)} ],

    [ ?x, proc{|val|
        begin
          inf = {}
          Hash[*(TkComm.list(val))].each{|k, v|
            if keyinfo = KEY_TBL.assoc(k[0])
              if cmd = PROC_TBL.assoc(keyinfo[1])
                begin
                  new_v = cmd.call(v)
                  v = new_v
                rescue
                end
              end
            end
            inf[k] = v
          }
          inf
        rescue
          val
        end
      } ],

    nil
  ]

=begin
  KEY_TBL.map!{|inf|
    if inf.kind_of?(Array)
      inf[0] = inf[0].getbyte(0) if inf[0].kind_of?(String)
      inf[1] = inf[1].getbyte(0) if inf[1].kind_of?(String)
    end
    inf
  }

  PROC_TBL.map!{|inf|
    if inf.kind_of?(Array)
      inf[0] = inf[0].getbyte(0) if inf[0].kind_of?(String)
    end
    inf
  }
=end

  _setup_subst_table(KEY_TBL, PROC_TBL);
end


module Tk::TreeCtrl::ConfigMethod
  include TkItemConfigMethod

  def treectrl_tagid(key, obj)
    if key.kind_of?(Array)
      key = key.join(' ')
    else
      key = key.to_s
    end

    if (obj.kind_of?(Tk::TreeCtrl::Column) ||
        obj.kind_of?(Tk::TreeCtrl::Element) ||
        obj.kind_of?(Tk::TreeCtrl::Item) ||
        obj.kind_of?(Tk::TreeCtrl::Style))
      obj = obj.id
    end

    case key
    when 'column'
      obj

    when 'debug'
      None

    when 'dragimage'
      None

    when 'element'
      obj

    when 'item element'
      obj

    when 'marquee'
      None

    when 'notify'
      obj

    when 'style'
      obj

    else
      obj
    end
  end

  def tagid(mixed_id)
    if mixed_id == 'debug'
      ['debug', None]
    elsif mixed_id == 'dragimage'
      ['dragimage', None]
    elsif mixed_id == 'marquee'
      ['marquee', None]
    elsif mixed_id.kind_of?(Array)
      [mixed_id[0], treectrl_tagid(*mixed_id)]
    else
      tagid(mixed_id.split(':'))
    end
  end

  def __item_cget_cmd(mixed_id)
    if mixed_id[0] == 'column' && mixed_id[1] == 'drag'
      return [self.path, 'column', 'dragcget']
    end

    if mixed_id[1].kind_of?(Array)
      id = mixed_id[1]
    else
      id = [mixed_id[1]]
    end

    if mixed_id[0].kind_of?(Array)
      ([self.path].concat(mixed_id[0]) << 'cget').concat(id)
    else
      [self.path, mixed_id[0], 'cget'].concat(id)
    end
  end
  private :__item_cget_cmd

  def __item_config_cmd(mixed_id)
    if mixed_id[0] == 'column' && mixed_id[1] == 'drag'
      return [self.path, 'column', 'dragconfigure']
    end

    if mixed_id[1].kind_of?(Array)
      id = mixed_id[1]
    else
      id = [mixed_id[1]]
    end

    if mixed_id[0].kind_of?(Array)
      ([self.path].concat(mixed_id[0]) << 'configure').concat(id)
    else
      [self.path, mixed_id[0], 'configure'].concat(id)
    end
  end
  private :__item_config_cmd

  def __item_pathname(id)
    if id.kind_of?(Array)
      key = id[0]
      if key.kind_of?(Array)
        key = key.join(' ')
      end

      tag = id[1]
      if tag.kind_of?(Array)
        tag = tag.join(' ')
      end

      id = [key, tag].join(':')
    end
    [self.path, id].join(';')
  end
  private :__item_pathname

  def __item_configinfo_struct(id)
    if id.kind_of?(Array) && id[0].to_s == 'notify'
      {:key=>0, :alias=>nil, :db_name=>nil, :db_class=>nil,
        :default_value=>nil, :current_value=>1}
    else
      {:key=>0, :alias=>1, :db_name=>1, :db_class=>2,
        :default_value=>3, :current_value=>4}
    end
  end
  private :__item_configinfo_struct


  def __item_font_optkeys(id)
    if id.kind_of?(Array) && (id[0] == 'element' ||
                              (id[0].kind_of?(Array) && id[0][1] == 'element'))
      []
    else
      ['font']
    end
  end
  private :__item_font_optkeys

  def __item_numstrval_optkeys(id)
    if id == 'debug'
      ['displaydelay']
    else
      super(id)
    end
  end
  private :__item_numstrval_optkeys

  def __item_boolval_optkeys(id)
    if id == 'debug'
      ['data', 'display', 'enable', 'span', 'textlayout']
    elsif id == 'dragimage'
      ['visible']
    elsif id == 'marquee'
      ['visible']
    elsif id.kind_of?(Array)
      case id[0]
      when 'item'
        ['visible', 'wrap', 'open', 'returnid', 'visible']
      when 'column'
        if id[1] == 'drag'
          ['enable']
        else
          ['button', 'expand', 'resize', 'squeeze', 'sunken',
            'visible', 'widthhack']
        end
      when 'element'
        ['draw', 'filled', 'showfocus', 'clip', 'destroy']
      when 'notify'
        ['active']
      when 'style'
        ['detach', 'indent', 'visible']
      else
        if id[0].kind_of?(Array) && id[0][1] == 'element'
          ['filled', 'showfocus']
        else
          super(id)
        end
      end
    else
      super(id)
    end
  end
  private :__item_boolval_optkeys

  def __item_strval_optkeys(id)
    if id == 'debug'
      ['erasecolor']
    elsif id.kind_of?(Array)
      case id[0]
      when 'column'
        if id[1] == 'drag'
          ['indicatorcolor']
        else
          super(id) << 'textcolor'
        end
      when 'element'
        super(id) << 'fill' << 'outline' << 'format'
      else
        super(id)
      end
    else
      super(id)
    end
  end
  private :__item_strval_optkeys

  def __item_listval_optkeys(id)
    if id.kind_of?(Array)
      case id[0]
      when 'column'
        ['itembackground']
      when 'element'
        ['relief']
      when 'style'
        ['union']
      else
        if id[0].kind_of?(Array) && id[0][1] == 'element'
          ['relief']
        else
          []
        end
      end
    else
      []
    end
  end
  private :__item_listval_optkeys

  def __item_val2ruby_optkeys(id)
    if id.kind_of?(Array)
      case id[0]
      when 'item'
        { 'button' => proc{|id,val| (val == 'auto')? val: TkComm.bool(val)} }
      else
        []
      end
    else
      []
    end
  end
  private :__item_val2ruby_optkeys

  def __item_keyonly_optkeys(id)  # { def_key=>(undef_key|nil), ... }
    {
      'notreally'=>nil,
      'increasing'=>'decreasing',
      'decreasing'=>'increasing',
      'ascii'=>nil,
      'dictionary'=>nil,
      'integer'=>nil,
      'real'=>nil
    }
  end
  private :__item_keyonly_optkeys

  def column_cget_tkstring(tagOrId, option)
    itemcget_tkstring(['column', tagOrId], option)
  end
  def column_cget(tagOrId, option)
    itemcget(['column', tagOrId], option)
  end
  def column_cget_strict(tagOrId, option)
    itemcget_strict(['column', tagOrId], option)
  end
  def column_configure(tagOrId, slot, value=None)
    itemconfigure(['column', tagOrId], slot, value)
  end
  def column_configinfo(tagOrId, slot=nil)
    itemconfiginfo(['column', tagOrId], slot)
  end
  def current_column_configinfo(tagOrId, slot=nil)
    current_itemconfiginfo(['column', tagOrId], slot)
  end

  def column_dragcget_tkstring(option)
    itemcget_tkstring(['column', 'drag'], option)
  end
  def column_dragcget(option)
    itemcget(['column', 'drag'], option)
  end
  def column_dragcget_strict(option)
    itemcget_strict(['column', 'drag'], option)
  end
  def column_dragconfigure(slot, value=None)
    itemconfigure(['column', 'drag'], slot, value)
  end
  def column_dragconfiginfo(slot=nil)
    itemconfiginfo(['column', 'drag'], slot)
  end
  def current_column_dragconfiginfo(slot=nil)
    current_itemconfiginfo(['column', 'drag'], slot)
  end

  def debug_cget_tkstring(option)
    itemcget_tkstring('debug', option)
  end
  def debug_cget(option)
    itemcget('debug', option)
  end
  def debug_cget_strict(option)
    itemcget_strict('debug', option)
  end
  def debug_configure(slot, value=None)
    itemconfigure('debug', slot, value)
  end
  def debug_configinfo(slot=nil)
    itemconfiginfo('debug', slot)
  end
  def current_debug_configinfo(slot=nil)
    current_itemconfiginfo('debug', slot)
  end

  def dragimage_cget_tkstring(option)
    itemcget_tkstring('dragimage', option)
  end
  def dragimage_cget(option)
    itemcget('dragimage', option)
  end
  def dragimage_cget_strict(option)
    itemcget_strict('dragimage', option)
  end
  def dragimage_configure(slot, value=None)
    itemconfigure('dragimage', slot, value)
  end
  def dragimage_configinfo(slot=nil)
    itemconfiginfo('dragimage', slot)
  end
  def current_dragimage_configinfo(slot=nil)
    current_itemconfiginfo('dragimage', slot)
  end

  def element_cget_tkstring(tagOrId, option)
    itemcget_tkstring(['element', tagOrId], option)
  end
  def element_cget(tagOrId, option)
    itemcget(['element', tagOrId], option)
  end
  def element_cget_strict(tagOrId, option)
    itemcget_strict(['element', tagOrId], option)
  end
  def element_configure(tagOrId, slot, value=None)
    itemconfigure(['element', tagOrId], slot, value)
  end
  def element_configinfo(tagOrId, slot=nil)
    itemconfiginfo(['element', tagOrId], slot)
  end
  def current_element_configinfo(tagOrId, slot=nil)
    current_itemconfiginfo(['element', tagOrId], slot)
  end

  def item_cget_tkstring(tagOrId, option)
    itemcget_tkstring(['item', tagOrId], option)
  end
  def item_cget(tagOrId, option)
    itemcget(['item', tagOrId], option)
  end
  def item_cget_strict(tagOrId, option)
    itemcget_strict(['item', tagOrId], option)
  end
  def item_configure(tagOrId, slot, value=None)
    itemconfigure(['item', tagOrId], slot, value)
  end
  def item_configinfo(tagOrId, slot=nil)
    itemconfiginfo(['item', tagOrId], slot)
  end
  def current_item_configinfo(tagOrId, slot=nil)
    current_itemconfiginfo(['item', tagOrId], slot)
  end

  def item_element_cget_tkstring(item, column, elem, option)
    itemcget_tkstring([['item', 'element'], [item, column, elem]], option)
  end
  def item_element_cget(item, column, elem, option)
    itemcget([['item', 'element'], [item, column, elem]], option)
  end
  def item_element_cget_strict(item, column, elem, option)
    itemcget_strict([['item', 'element'], [item, column, elem]], option)
  end
  def item_element_configure(item, column, elem, slot, value=None)
    itemconfigure([['item', 'element'], [item, column, elem]], slot, value)
  end
  def item_element_configinfo(item, column, elem, slot=nil)
    itemconfiginfo([['item', 'element'], [item, column, elem]], slot)
  end
  def current_item_element_configinfo(item, column, elem, slot=nil)
    current_itemconfiginfo([['item', 'element'], [item, column, elem]], slot)
  end

  def marquee_cget_tkstring(option)
    itemcget_tkstring('marquee', option)
  end
  def marquee_cget(option)
    itemcget('marquee', option)
  end
  def marquee_cget_strict(option)
    itemcget_strict('marquee', option)
  end
  def marquee_configure(slot, value=None)
    itemconfigure('marquee', slot, value)
  end
  def marquee_configinfo(slot=nil)
    itemconfiginfo('marquee', slot)
  end
  def current_marquee_configinfo(slot=nil)
    current_itemconfiginfo('marquee', slot)
  end

  def notify_cget_tkstring(win, pattern, option)
    pattern = "<#{pattern}>"
    tk_split_simplelist(tk_call_without_enc(*(__item_confinfo_cmd(tagid(['notify', [win, pattern]])) << "-#{option}")), false, true)[-1]
  end
  def notify_cget(win, pattern, option)
    pattern = "<#{pattern}>"
    current_itemconfiginfo(['notify', [win, pattern]])[option.to_s]
  end
  def notify_cget_strict(win, pattern, option)
    pattern = "<#{pattern}>"
    info = current_itemconfiginfo(['notify', [win, pattern]])
    option = option.to_s
    unless info.has_key?(option)
      fail RuntimeError, "unknown option \"#{option}\""
    else
      info[option]
    end
  end
  def notify_configure(win, pattern, slot, value=None)
    pattern = "<#{pattern}>"
    itemconfigure(['notify', [win, pattern]], slot, value)
  end
  def notify_configinfo(win, pattern, slot=nil)
    pattern = "<#{pattern}>"
    itemconfiginfo(['notify', [win, pattern]], slot)
  end
  def current_notify_configinfo(tagOrId, slot=nil)
    pattern = "<#{pattern}>"
    current_itemconfiginfo(['notify', [win, pattern]], slot)
  end

  def style_cget_tkstring(tagOrId, option)
    itemcget_tkstring(['style', tagOrId], option)
  end
  def style_cget(tagOrId, option)
    itemcget(['style', tagOrId], option)
  end
  def style_cget_strict(tagOrId, option)
    itemcget_strict(['style', tagOrId], option)
  end
  def style_configure(tagOrId, slot, value=None)
    itemconfigure(['style', tagOrId], slot, value)
  end
  def style_configinfo(tagOrId, slot=nil)
    itemconfiginfo(['style', tagOrId], slot)
  end
  def current_style_configinfo(tagOrId, slot=nil)
    current_itemconfiginfo(['style', tagOrId], slot)
  end

  private :itemcget_tkstring, :itemcget, :itemcget_strict
  private :itemconfigure, :itemconfiginfo, :current_itemconfiginfo
end


class Tk::TreeCtrl
  include Tk::TreeCtrl::ConfigMethod
  include Scrollable

  TkCommandNames = ['treectrl'.freeze].freeze
  WidgetClassName = 'TreeCtrl'.freeze
  WidgetClassNames[WidgetClassName] ||= self


  def __destroy_hook__
    Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.delete(@path)
    }
    Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.delete(@path)
    }
    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.delete(@path)
    }
    Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.delete(@path)
    }
  end


  def __strval_optkeys
    super() + [
      'buttoncolor', 'columnprefix', 'itemprefix', 'linecolor'
    ]
  end
  private :__strval_optkeys

  def __boolval_optkeys
    [
      'itemwidthequal', 'usetheme',
      'showbuttons', 'showheader', 'showlines', 'showroot',
      'showrootbutton', 'showrootlines', 'showrootchildbuttons'
    ]
  end
  private :__boolval_optkeys

  def __listval_optkeys
    [ 'defaultstyle' ]
  end
  private :__listval_optkeys


  def install_bind(cmd, *args)
    install_bind_for_event_class(Tk::TreeCtrl::NotifyEvent, cmd, *args)
  end


  def create_self(keys)
    if keys and keys != None
      tk_call_without_enc(self.class::TkCommandNames[0], @path,
                          *hash_kv(keys, true))
    else
      tk_call_without_enc(self.class::TkCommandNames[0], @path)
    end
  end
  private :create_self


  def activate(desc)
    tk_send('activate', desc)
    self
  end

  def canvasx(x)
    number(tk_send('canvasx', x))
  end

  def canvasy(y)
    number(tk_send('canvasy', y))
  end

  def collapse(*dsc)
    tk_send_without_enc('collapse', *(dsc.map!{|d| _get_eval_string(d, true)}))
    self
  end

  def collapse_recurse(*dsc)
    tk_send_without_enc('collapse', '-recurse',
                        *(dsc.map!{|d| _get_eval_string(d, true)}))
    self
  end

  def column_bbox(idx)
    list(tk_send('column', 'bbox', idx))
  end

  def column_compare(column1, op, column2)
    bool(tk_send('column', 'compare', column1, op, column2))
  end

  def column_count
    num_or_str(tk_send('column', 'count'))
  end

  def column_create(keys=nil)
    if keys && keys.kind_of?(Hash)
      num_or_str(tk_send('column', 'create', *hash_kv(keys)))
    else
      num_or_str(tk_send('column', 'create'))
    end
  end

  def column_delete(idx)
    Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[self.path]
        Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[self.path].delete(idx)
      end
    }
    tk_send('column', 'delete', idx)
    self
  end

  def column_index(idx)
    num_or_str(tk_send('column', 'index', idx))
  end

  def column_id(idx)
    tk_send('column', 'id', idx)
  end

  def column_list(visible=false)
    if visible
      simplelist(tk_send('column', 'list', '-visible'))
    else
      simplelist(tk_send('column', 'list'))
    end
  end
  def column_visible_list
    column_list(true)
  end

  def column_move(idx, before)
    tk_send('column', 'move', idx, before)
    self
  end

  def column_needed_width(idx)
    num_or_str(tk_send('column', 'neededwidth', idx))
  end
  alias column_neededwidth column_needed_width

  def column_order(column, visible=false)
    if visible
      num_or_str(tk_send('column', 'order', column, '-visible'))
    else
      num_or_str(tk_send('column', 'order', column))
    end
  end
  def column_visible_order(column)
    column_order(column, true)
  end

  def column_width(idx)
    num_or_str(tk_send('column', 'width', idx))
  end

  def compare(item1, op, item2)
    bool(tk_send('compare', item1, op, item2))
  end

  def contentbox()
    list(tk_send('contentbox'))
  end

  def depth(item=None)
    num_or_str(tk_send_without_enc('depth', _get_eval_string(item, true)))
  end

  def dragimage_add(item, *args)
    tk_send('dragimage', 'add', item, *args)
    self
  end

  def dragimage_clear()
    tk_send('dragimage', 'clear')
    self
  end

  def dragimage_offset(*args) # x, y
    if args.empty?
      list(tk_send('dragimage', 'offset'))
    else
      tk_send('dragimage', 'offset', *args)
      self
    end
  end

  def dragimage_visible(*args) # mode
    if args..empty?
      bool(tk_send('dragimage', 'visible'))
    else
      tk_send('dragimage', 'visible', *args)
      self
    end
  end
  def dragimage_visible?
    dragimage_visible()
  end

  def debug_dinfo
    tk_send('debug', 'dinfo')
    self
  end

  def debug_scroll
    tk_send('debug', 'scroll')
  end

  def element_create(elem, type, keys=nil)
    if keys && keys.kind_of?(Hash)
      tk_send('element', 'create', elem, type, *hash_kv(keys))
    else
      tk_send('element', 'create', elem, type)
    end
  end

  def element_delete(*elems)
    Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[self.path]
        elems.each{|elem|
          Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[self.path].delete(elem)
        }
      end
    }
    tk_send('element', 'delete', *elems)
    self
  end

  def element_names()
    list(tk_send('element', 'names')).collect!{|elem|
      Tk::TreeCtrl::Element.id2obj(self, elem)
    }
  end

  def _conv_element_perstate_val(opt, val)
    case opt
    when 'background', 'foreground', 'fill', 'outline', 'format'
      val
    when 'draw', 'filled', 'showfocus', 'destroy'
      bool(val)
    else
      tk_tcl2ruby(val)
    end
  end
  private :_conv_element_perstate_val

  def element_perstate(elem, opt, st_list)
    tk_send('element', 'perstate', elem, "-{opt}", st_list)
  end

  def element_type(elem)
    tk_send('element', 'type', elem)
  end

  def element_class(elem)
    Tk::TreeCtrl::Element.type2class(element_type(elem))
  end

  def expand(*dsc)
    tk_send('expand', *dsc)
    self
  end

  def expand_recurse(*dsc)
    tk_send('expand', '-recurse', *dsc)
    self
  end

  def identify(x, y)
    lst = list(tk_send('identify', x, y))

    if lst[0] == 'item'
      lst[1] = Tk::TreeCtrl::Item.id2obj(self, lst[1])
      size = lst.size
      i = 2
      while i < size
        case lst[i]
        when 'line'
          i += 1
          lst[i] = Tk::TreeCtrl::Item.id2obj(self, lst[i])
          i += 1

        when 'button'
          i += 1

        when 'column'
          i += 2

        when 'elem'
          i += 1
          lst[i] = Tk::TreeCtrl::Element.id2obj(self, lst[i])
          i += 1

        else
          i += 1
        end
      end
    end

    lst
  end

  def index(idx)
    num_or_str(tk_send('index', idx))
  end

  def item_ancestors(item)
    list(tk_send('item', 'ancestors', item)).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def item_bbox(item, *args)
    list(tk_send('item', 'bbox', item, *args))
  end

  def item_children(item)
    list(tk_send('item', 'children', item)).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def item_collapse(item)
    tk_send_without_enc('item', 'collapse', _get_eval_string(item, true))
    self
  end

  def item_collapse_recurse(item)
    tk_send_without_enc('item', 'collapse',
                        _get_eval_string(item, true), '-recurse')
    self
  end

  def item_compare(item1, op, item2)
    bool(tk_send('item', 'compare', item1, op, item2))
  end

  def item_complex(item, *args)
    tk_send_without_enc('item', 'complex',
                        _get_eval_string(item, true),
                        *(args.map!{|arg| _get_eval_string(arg, true)}))
    self
  end

  def item_count
    num_or_str(tk_send('item', 'count'))
  end

  def item_create(keys={})
    num_or_str(tk_send_without_enc('item', 'create', *hash_kv(keys, true)))
  end

  def _erase_children(item)
    item_children(item).each{|i| _erase_children(i)}
    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[self.path].delete(item)
  end
  private :_erase_children

  def item_delete(first, last=None)
    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[self.path]
        if first == 'all' || first == :all || last == 'all' || last == :all
          Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[self.path].clear
        elsif last == None
          _erase_children(first)
        else
          self.range(first, last).each{|id|
            _erase_children(id)
          }
        end
      end
    }
    tk_send('item', 'delete', first, last)
    self
  end

  def item_dump(item)
    list(tk_send('item', 'dump', item))
  end

  def item_dump_hash(item)
    Hash[*list(tk_send('item', 'dump', item))]
  end

  def item_element_actual(item, column, elem, key)
    tk_send('item', 'element', 'actual', item, column, elem, "-#{key}")
  end

  def item_element_perstate(elem, opt, st_list)
    tk_send('item', 'element', 'perstate', elem, "-{opt}", st_list)
  end

  def item_expand(item)
    tk_send('item', 'expand', item)
    self
  end

  def item_expand_recurse(item)
    tk_send('item', 'expand', item, '-recurse')
    self
  end

  def item_firstchild(parent, child=nil)
    if child
      tk_send_without_enc('item', 'firstchild',
                          _get_eval_string(parent, true),
                          _get_eval_string(child, true))
      self
    else
      id = num_or_str(tk_send_without_enc('item', 'firstchild',
                                          _get_eval_string(parent, true)))
      Tk::TreeCtrl::Item.id2obj(self, id)
    end
  end
  alias item_first_child item_firstchild

  def item_hasbutton(item, st=None)
    if st == None
      bool(tk_send_without_enc('item', 'hasbutton',
                               _get_eval_string(item, true)))
    else
      tk_send_without_enc('item', 'hasbutton',
                          _get_eval_string(item, true),
                          _get_eval_string(st))
      self
    end
  end
  alias item_has_button item_hasbutton

  def item_hasbutton?(item)
    item_hasbutton(item)
  end
  alias item_has_button? item_hasbutton?

  def item_id(item)
    tk_send('item', 'id', item)
  end

  def item_image(item, column=nil, *args)
    if args.empty?
      if column
        img = tk_send('item', 'image', item, column)
        TkImage::Tk_IMGTBL[img]? TkImage::Tk_IMGTBL[img] : img
      else
        simplelist(tk_send('item', 'image', item)).collect!{|img|
          TkImage::Tk_IMGTBL[img]? TkImage::Tk_IMGTBL[img] : img
        }
      end
    else
      tk_send('item', 'image', item, column, *args)
      self
    end
  end
  def get_item_image(item, column=nil)
    item_image(item, column)
  end
  def set_item_image(item, col, img, *args)
    item_image(item, col, img, *args)
  end

  def item_index(item)
    list(tk_send('item', 'index', item))
  end

  def item_isancestor(item, des)
    bool(tk_send('item', 'isancestor', item, des))
  end
  alias item_is_ancestor  item_isancestor
  alias item_isancestor?  item_isancestor
  alias item_is_ancestor? item_isancestor

  def item_isopen(item)
    bool(tk_send('item', 'isopen', item))
  end
  alias item_is_open    item_isopen
  alias item_isopen?    item_isopen
  alias item_is_open?   item_isopen
  alias item_isopened?  item_isopen
  alias item_is_opened? item_isopen

  def item_lastchild(parent, child=nil)
    if child
      tk_send_without_enc('item', 'lastchild',
                          _get_eval_string(parent, true),
                          _get_eval_string(child, true))
      self
    else
      id = num_or_str(tk_send_without_enc('item', 'lastchild',
                                          _get_eval_string(parent, true)))
      Tk::TreeCtrl::Item.id2obj(self, id)
    end
  end
  alias item_last_child item_lastchild

  def item_nextsibling(sibling, nxt=nil)
    if nxt
      tk_send('item', 'nextsibling', sibling, nxt)
      self
    else
      id = num_or_str(tk_send('item', 'nextsibling', sibling))
      Tk::TreeCtrl::Item.id2obj(self, id)
    end
  end
  alias item_next_sibling item_nextsibling

  def item_numchildren(item)
    number(tk_send_without_enc('item', 'numchildren',
                               _get_eval_string(item, true)))
  end
  alias item_num_children  item_numchildren
  alias item_children_size item_numchildren

  def item_order(item, visible=false)
    if visible
      ret = num_or_str(tk_send('item', 'order', item, '-visible'))
    else
      ret = num_or_str(tk_send('item', 'order', item))
    end

    (ret.kind_of?(Fixnum) && ret < 0)? nil: ret
  end
  def item_visible_order(item)
    item_order(item, true)
  end

  def item_parent(item)
    id = num_or_str(tk_send('item', 'parent', item))
    Tk::TreeCtrl::Item.id2obj(self, id)
  end

  def item_prevsibling(sibling, prev=nil)
    if prev
      tk_send('item', 'prevsibling', sibling, prev)
      self
    else
      id = num_or_str(tk_send('item', 'prevsibling', sibling))
      Tk::TreeCtrl::Item.id2obj(self, id)
    end
  end
  alias item_prev_sibling item_prevsibling

  def item_range(first, last)
    simplelist(tk_send('item', 'range', first, last))
  end

  def item_remove(item)
    tk_send('item', 'remove', item)
    self
  end

  def item_rnc(item)
    list(tk_send('item', 'rnc', item))
  end

  def _item_sort_core(real_sort, item, *opts)
    opts = opts.collect{|param|
      if param.kind_of?(Hash)
        param = _symbolkey2str(param)
        if param.key?('column')
          key = '-column'
          desc = param.delete('column')
        elsif param.key?('element')
          key = '-element'
          desc = param.delete('element')
        else
          key = nil
        end

        if param.empty?
          param = None
        else
          param = hash_kv(__conv_item_keyonly_opts(item, param))
        end

        if key
          [key, desc].concat(param)
        else
          param
        end

      elsif param.kind_of?(Array)
        if param[2].kind_of?(Hash)
          param[2] = hash_kv(__conv_item_keyonly_opts(item, param[2]))
        end
        param

      elsif param.kind_of?(String) && param =~ /\A[a-z]+\Z/
        '-' << param

      elsif param.kind_of?(Symbol)
        '-' << param.to_s

      else
        param
      end
    }.flatten

    if real_sort
      tk_send('item', 'sort', item, *opts)
      self
    else
      list(tk_send('item', 'sort', item, '-notreally', *opts))
    end
  end
  private :_item_sort_core

  def item_sort(item, *opts)
    _item_sort_core(true, item, *opts)
  end
  def item_sort_not_really(item, *opts)
    _item_sort_core(false, item, *opts)
  end

  def item_span(item, column=nil, *args)
    if args.empty?
      if column
        list(tk_send('item', 'span', item, column))
      else
        simplelist(tk_send('item', 'span', item)).collect!{|elem| list(elem)}
      end
    else
      tk_send('item', 'span', item, column, *args)
      self
    end
  end
  def get_item_span(item, column=nil)
    item_span(item, column)
  end
  def set_item_span(item, col, num, *args)
    item_span(item, col, num, *args)
  end

  def item_state_forcolumn(item, column, *args)
    tk_send('item', 'state', 'forcolumn', item, column, *args)
  end
  alias item_state_for_column item_state_forcolumn

  def item_state_get(item, *args)
    if args.empty?
      list(tk_send('item', 'state', 'get', item *args))
    else
      bool(tk_send('item', 'state', 'get', item))
    end
  end

  def item_state_set(item, *args)
    tk_send('item', 'state', 'set', item, *args)
  end

  def item_style_elements(item, column)
    list(tk_send('item', 'style', 'elements', item, column)).collect!{|id|
      Tk::TreeCtrl::Style.id2obj(self, id)
    }
  end

  def item_style_map(item, column, style, map)
    tk_send('item', 'style', 'map', item, column, style, map)
    self
  end

  def item_style_set(item, column=nil, *args)
    if args.empty?
      if column
        id = tk_send_without_enc('item', 'style', 'set',
                                 _get_eval_string(item, true),
                                 _get_eval_string(column, true))
        Tk::TreeCtrl::Style.id2obj(self, id)
      else
        list(tk_send_without_enc('item', 'style', 'set',
                                 _get_eval_string(item, true))).collect!{|id|
          Tk::TreeCtrl::Style.id2obj(self, id)
        }
      end
    else
      tk_send_without_enc('item', 'style', 'set',
                          _get_eval_string(item, true),
                          _get_eval_string(column, true),
                          *(args.flatten.map!{|arg|
                              _get_eval_string(arg, true)
                            }))
      self
    end
  end

  def item_text(item, column, txt=nil, *args)
    if args.empty?
      if txt
        tk_send('item', 'text', item, column, txt)
        self
      else
        tk_send('item', 'text', item, column)
      end
    else
      tk_send('item', 'text', item, column, txt, *args)
      self
    end
  end

  def item_toggle(item)
    tk_send('item', 'toggle', item)
    self
  end

  def item_toggle_recurse(item)
    tk_send('item', 'toggle', item, '-recurse')
    self
  end

  def item_visible(item, st=None)
    if st == None
      bool(tk_send('item', 'visible', item))
    else
      tk_send('item', 'visible', item, st)
      self
    end
  end
  def item_visible?(item)
    item_visible(item)
  end

  def marquee_anchor(*args)
    if args.empty?
      list(tk_send('marquee', 'anchor'))
    else
      tk_send('marquee', 'anchor', *args)
      self
    end
  end

  def marquee_coords(*args)
    if args.empty?
      list(tk_send('marquee', 'coords'))
    else
      tk_send('marquee', 'coords', *args)
      self
    end
  end

  def marquee_corner(*args)
    if args.empty?
      tk_send('marquee', 'corner')
    else
      tk_send('marquee', 'corner', *args)
      self
    end
  end

  def marquee_identify()
    list(tk_send('marquee', 'identify')).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def marquee_visible(st=None)
    if st == None
      bool(tk_send('marquee', 'visible'))
    else
      tk_send('marquee', 'visible', st)
      self
    end
  end
  def marquee_visible?()
    marquee_visible()
  end

  def notify_bind(obj, event, *args)
    if TkComm._callback_entry?(args[0]) || !block_given?
      cmd = args.shift
    else
      cmd = Proc.new
    end
    _bind([@path, 'notify', 'bind', obj], event, cmd, *args)
    self
  end

  def notify_bind_append(obj, event, *args)
    if TkComm._callback_entry?(args[0]) || !block_given?
      cmd = args.shift
    else
      cmd = Proc.new
    end
    _bind_append([@path, 'notify', 'bind', obj], event, cmd, *args)
    self
  end

  def notify_bind_remove(obj, event)
    _bind_remove([@path, 'notify', 'bind', obj], event)
    self
  end

  def notify_bindinfo(obj, event=nil)
    _bindinfo([@path, 'notify', 'bind', obj], event)
  end

  def notify_detailnames(event)
    list(tk_send('notify', 'detailnames', event))
  end

  def notify_eventnames()
    list(tk_send('notify', 'eventnames'))
  end

  def notify_generate(pattern, char_map=None, percents_cmd=None)
    pattern = "<#{pattern}>"
    tk_send('notify', 'generate', pattern, char_map, percents_cmd)
    self
  end

  def notify_install(pattern, percents_cmd=nil, &b)
    pattern = "<#{pattern}>"
    percents_cmd = Proc.new(&b) if !percents_cmd && b
    if percents_cmd
      procedure(tk_send('notify', 'install', pattern, percents_cmd))
    else
      procedure(tk_send('notify', 'install', pattern))
    end
  end

  def notify_install_detail(event, detail, percents_cmd=nil, &b)
    percents_cmd = Proc.new(&b) if !percents_cmd && b
    if percents_cmd
      tk_send('notify', 'install', 'detail', event, detail, percents_cmd)
    else
      tk_send('notify', 'install', 'detail', event, detail)
    end
  end

  def notify_install_event(event, percents_cmd=nil, &b)
    percents_cmd = Proc.new(&b) if !percents_cmd && b
    if percents_cmd
      tk_send('notify', 'install', 'event', event, percents_cmd)
    else
      tk_send('notify', 'install', 'event', event)
    end
  end

  def notify_linkage(pattern, detail=None)
    if detail != None
      tk_send('notify', 'linkage', pattern, detail)
    else
      begin
        if pattern.to_s.index(?-)
          begin
            tk_send('notify', 'linkage', "<#{pattern}>")
          rescue
            tk_send('notify', 'linkage', pattern)
          end
        else
          begin
            tk_send('notify', 'linkage', pattern)
          rescue
            tk_send('notify', 'linkage', "<#{pattern}>")
          end
        end
      end
    end
  end

  def notify_unbind(pattern=nil)
    if pattern
      tk_send('notify', 'unbind', "<#{pattern}>")
    else
      tk_send('notify', 'unbind')
    end
    self
  end

  def notify_uninstall(pattern)
    pattern = "<#{pattern}>"
    tk_send('notify', 'uninstall', pattern)
    self
  end

  def notify_uninstall_detail(event, detail)
    tk_send('notify', 'uninstall', 'detail', event, detail)
    self
  end

  def notify_uninstall_event(event)
    tk_send('notify', 'uninstall', 'event', event)
    self
  end

  def numcolumns()
    num_or_str(tk_send('numcolumns'))
  end
  alias num_columns  numcolumns
  alias columns_size numcolumns

  def numitems()
    num_or_str(tk_send('numitems'))
  end
  alias num_items  numitems
  alias items_size numitems

  def orphans()
    list(tk_send('orphans')).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def range(first, last)
    list(tk_send('range', first, last)).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def state_define(name)
    tk_send('state', 'define', name)
    self
  end

  def state_linkage(name)
    tk_send('state', 'linkage', name)
  end

  def state_names()
    list(tk_send('state', 'names'))
  end

  def state_undefine(*names)
    tk_send('state', 'undefine', *names)
    self
  end

  def see(item, column=None, keys={})
    tk_send('see', item, column, *hash_kv(keys))
    self
  end

  def selection_add(first, last=None)
    tk_send('selection', 'add', first, last)
    self
  end

  def selection_anchor(item=None)
    id = num_or_str(tk_send('selection', 'anchor', item))
    Tk::TreeCtrl::Item.id2obj(self, id)
  end

  def selection_clear(*args) # first, last
    tk_send('selection', 'clear', *args)
    self
  end

  def selection_count()
    number(tk_send('selection', 'count'))
  end

  def selection_get()
    list(tk_send('selection', 'get')).collect!{|id|
      Tk::TreeCtrl::Item.id2obj(self, id)
    }
  end

  def selection_includes(item)
    bool(tk_send('selection', 'includes', item))
  end

  def selection_modify(sel, desel)
    tk_send('selection', 'modify', sel, desel)
    self
  end

  def style_create(style, keys=None)
    if keys && keys != None
      tk_send('style', 'create', style, *hash_kv(keys))
    else
      tk_send('style', 'create', style)
    end
  end

  def style_delete(*args)
    Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[self.path]
        args.each{|sty|
          Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[self.path].delete(sty)
        }
      end
    }
    tk_send('style', 'delete', *args)
    self
  end

  def style_elements(style, *elems)
    if elems.empty?
      list(tk_send('style', 'elements', style)).collect!{|id|
        Tk::TreeCtrl::Element.id2obj(self, id)
      }
    else
      tk_send('style', 'elements', style, elems.flatten)
      self
    end
  end

  def _conv_style_layout_val(sty, val)
    case sty.to_s
    when 'padx', 'pady', 'ipadx', 'ipady'
      lst = list(val)
      (lst.size == 1)? lst[0]: lst
    when 'detach', 'indent'
      bool(val)
    when 'union'
      simplelist(val).collect!{|elem|
        Tk::TreeCtrl::Element.id2obj(self, elem)
      }
    else
      val
    end
  end
  private :_conv_style_layout_val

  def style_layout(style, elem, keys=None)
    if keys && keys != None
      if keys.kind_of?(Hash)
        tk_send('style', 'layout', style, elem, *hash_kv(keys))
        self
      else
        _conv_style_layout_val(keys,
                               tk_send('style', 'layout',
                                       style, elem, "-#{keys}"))
      end
    else
      ret = Hash.new
      Hash[*simplelist(tk_send('style', 'layout', style, elem))].each{|k, v|
        k = k[1..-1]
        ret[k] = _conv_style_layout_val(k, v)
      }
      ret
    end
  end
  def get_style_layout(style, elem, opt=None)
    style_layout(style, elem, opt)
  end
  def set_style_layout(style, elem, slot, value=None)
    if slot.kind_of?(Hash)
      style_layout(style, elem, slot)
    else
      style_layout(style, elem, {slot=>value})
    end
  end

  def style_names()
    list(tk_send('style', 'names')).collect!{|id|
      Tk::TreeCtrl::Style.id2obj(self, id)
    }
  end

  def toggle(*items)
    tk_send('toggle', *items)
    self
  end

  def toggle_recurse()
    tk_send('toggle', '-recurse', *items)
    self
  end
end


class Tk::TreeCtrl::Column < TkObject
  TreeCtrlColumnID_TBL = TkCore::INTERP.create_table

  #nodyna <instance_eval-1640> <IEV MODERATE (method definition)>
  (TreeCtrlColumnID = ['treectrl_column'.freeze, TkUtil.untrust('00000')]).instance_eval{
    @mutex = Mutex.new
    def mutex; @mutex; end
    freeze
  }

  TkCore::INTERP.init_ip_env{
    Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.clear
    }
  }

  def self.id2obj(tree, id)
    tpath = tree.path
    Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[tpath]
        Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[tpath][id]? \
                   Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[tpath][id] : id
      else
        id
      end
    }
  end

  def initialize(parent, keys={})
    @tree = parent
    @tpath = parent.path

    keys = _symbolkey2str(keys)

    Tk::TreeCtrl::Column::TreeCtrlColumnID.mutex.synchronize{
      @path = @id =
        keys.delete('tag') ||
        Tk::TreeCtrl::Column::TreeCtrlColumnID.join(TkCore::INTERP._ip_id_)
      Tk::TreeCtrl::Column::TreeCtrlColumnID[1].succ!
    }

    keys['tag'] = @id

    Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[@tpath] ||= {}
      Tk::TreeCtrl::Column::TreeCtrlColumnID_TBL[@tpath][@id] = self
    }

    @tree.column_create(keys)
  end

  def id
    @id
  end

  def to_s
    @id.to_s.dup
  end

  def cget_tkstring(opt)
    @tree.column_cget_tkstring(@tree.column_index(@id), opt)
  end
  def cget(opt)
    @tree.column_cget(@tree.column_index(@id), opt)
  end
  def cget_strict(opt)
    @tree.column_cget_strict(@tree.column_index(@id), opt)
  end

  def configure(*args)
    @tree.column_configure(@tree.column_index(@id), *args)
  end

  def configinfo(*args)
    @tree.column_configinfo(@tree.column_index(@id), *args)
  end

  def current_configinfo(*args)
    @tree.current_column_configinfo(@tree.column_index(@id), *args)
  end

  def delete
    @tree.column_delete(@tree.column_index(@id))
    self
  end

  def index
    @tree.column_index(@id)
  end

  def move(before)
    @tree.column_move(@tree.column_index(@id), before)
    self
  end

  def needed_width
    @tree.column_needed_width(@tree.column_index(@id))
  end
  alias neededwidth needed_width

  def current_width
    @tree.column_width(@tree.column_index(@id))
  end
end


class Tk::TreeCtrl::Element < TkObject
  TreeCtrlElementID_TBL = TkCore::INTERP.create_table

  #nodyna <instance_eval-1641> <IEV MODERATE (method definition)>
  (TreeCtrlElementID = ['treectrl_element'.freeze, TkUtil.untrust('00000')]).instance_eval{
    @mutex = Mutex.new
    def mutex; @mutex; end
    freeze
  }
  TreeCtrlElemTypeToClass = {}

  TkCore::INTERP.init_ip_env{
    Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.clear
    }
  }

  def self.type2class(type)
    TreeCtrlElemTypeToClass[type] || type
  end

  def self.id2obj(tree, id)
    tpath = tree.path
    Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[tpath]
        Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[tpath][id]? \
                 Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[tpath][id] : id
      else
        id
      end
    }
  end

  def initialize(parent, type, keys=nil)
    @tree = parent
    @tpath = parent.path
    @type = type.to_s
    Tk::TreeCtrl::Element::TreeCtrlElementID.mutex.synchronize{
      @path = @id =
        Tk::TreeCtrl::Element::TreeCtrlElementID.join(TkCore::INTERP._ip_id_)
      Tk::TreeCtrl::Element::TreeCtrlElementID[1].succ!
    }

    Tk::TreeCtrl::Element::TreeCtrlElementID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[@tpath] ||= {}
      Tk::TreeCtrl::Element::TreeCtrlElementID_TBL[@tpath][@id] = self
    }

    @tree.element_create(@id, @type, keys)
  end

  def id
    @id
  end

  def to_s
    @id.dup
  end

  def cget_tkstring(opt)
    @tree.element_cget_tkstring(@id, opt)
  end
  def cget(opt)
    @tree.element_cget(@id, opt)
  end
  def cget_strict(opt)
    @tree.element_cget_strict(@id, opt)
  end

  def configure(*args)
    @tree.element_configure(@id, *args)
  end

  def configinfo(*args)
    @tree.element_configinfo(@id, *args)
  end

  def current_configinfo(*args)
    @tree.current_element_configinfo(@id, *args)
  end

  def delete
    @tree.element_delete(@id)
    self
  end

  def element_type
    @tree.element_type(@id)
  end

  def element_class
    @tree.element_class(@id)
  end
end

class Tk::TreeCtrl::BitmapElement < Tk::TreeCtrl::Element
  TreeCtrlElemTypeToClass['bitmap'] = self

  def initialize(parent, keys=nil)
    super(parent, 'bitmap', keys)
  end
end

class Tk::TreeCtrl::BorderElement < Tk::TreeCtrl::Element
  TreeCtrlElemTypeToClass['border'] = self

  def initialize(parent, keys=nil)
    super(parent, 'border', keys)
  end
end

class Tk::TreeCtrl::ImageElement < Tk::TreeCtrl::Element
  TreeCtrlElemTypeToClass['image'] = self

  def initialize(parent, keys=nil)
    super(parent, 'image', keys)
  end
end

class Tk::TreeCtrl::RectangleElement < Tk::TreeCtrl::Element
  TreeCtrlElemTypeToClass['rect'] = self

  def initialize(parent, keys=nil)
    super(parent, 'rect', keys)
  end
end


class Tk::TreeCtrl::Item < TkObject
  TreeCtrlItemID_TBL = TkCore::INTERP.create_table

  TkCore::INTERP.init_ip_env{
    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.clear
    }
  }

  def self.id2obj(tree, id)
    tpath = tree.path
    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[tpath]
        Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[tpath][id]? \
                        Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[tpath][id] : id
      else
        id
      end
    }
  end

  def initialize(parent, keys={})
    @tree = parent
    @tpath = parent.path
    @path = @id = @tree.item_create(keys)

    Tk::TreeCtrl::Item::TreeCtrlItemID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[@tpath] ||= {}
      Tk::TreeCtrl::Item::TreeCtrlItemID_TBL[@tpath][@id] = self
    }
  end

  def id
    @id
  end

  def to_s
    @id.to_s.dup
  end

  def ancestors
    @tree.item_ancestors(@id)
  end

  def bbox(*args)
    @tree.item_bbox(@id, *args)
  end

  def children
    @tree.item_children(@id)
  end

  def collapse
    @tree.item_collapse(@id)
    self
  end

  def collapse_recurse
    @tree.item_collapse_recurse(@id)
    self
  end

  def complex(*args)
    @tree.item_complex(@id, *args)
    self
  end

  def cget_tkstring(opt)
    @tree.item_cget_tkstring(@id, opt)
  end
  def cget(opt)
    @tree.item_cget(@id, opt)
  end
  def cget_strict(opt)
    @tree.item_cget_strict(@id, opt)
  end

  def configure(*args)
    @tree.item_configure(@id, *args)
  end

  def configinfo(*args)
    @tree.item_configinfo(@id, *args)
  end

  def current_configinfo(*args)
    @tree.current_item_configinfo(@id, *args)
  end

  def delete
    @tree.item_delete(@id)
    self
  end

  def element_dump
    @tree.item_dump(@id)
  end

  def element_dump_hash
    @tree.item_dump_hash(@id)
  end

  def element_actual(column, elem, key)
    @tree.item_element_actual(@id, column, elem, key)
  end

  def element_cget_tkstring(opt)
    @tree.item_element_cget(@id, opt)
  end
  def element_cget_tkstring(opt)
    @tree.item_element_cget(@id, opt)
  end
  def element_cget_strict(opt)
    @tree.item_element_cget_strict(@id, opt)
  end

  def element_configure(*args)
    @tree.item_element_configure(@id, *args)
  end

  def element_configinfo(*args)
    @tree.item_element_configinfo(@id, *args)
  end

  def current_element_configinfo(*args)
    @tree.current_item_element_configinfo(@id, *args)
  end

  def expand
    @tree.item_expand(@id)
    self
  end

  def expand_recurse
    @tree.item_expand_recurse(@id)
    self
  end

  def firstchild(child=nil)
    if child
      @tree.item_firstchild(@id, child)
      self
    else
      @tree.item_firstchild(@id)
    end
  end
  alias first_child firstchild

  def hasbutton(st=None)
    if st == None
      @tree.item_hasbutton(@id)
    else
      @tree.item_hasbutton(@id, st)
      self
    end
  end
  alias has_button hasbutton

  def hasbutton?
    @tree.item_hasbutton(@id)
  end
  alias has_button? hasbutton?

  def index
    @tree.item_index(@id)
  end

  def isancestor(des)
    @tree.item_isancestor(@id, des)
  end
  alias is_ancestor  isancestor
  alias isancestor?  isancestor
  alias is_ancestor? isancestor
  alias ancestor?    isancestor

  def isopen
    @tree.item_isopen(@id)
  end
  alias is_open    isopen
  alias isopen?    isopen
  alias is_open?   isopen
  alias isopened?  isopen
  alias is_opened? isopen
  alias open?      isopen

  def lastchild(child=nil)
    if child
      @tree.item_lastchild(@id, child)
      self
    else
      @tree.item_lastchild(@id)
    end
  end
  alias last_child lastchild

  def nextsibling(nxt=nil)
    if nxt
      @tree.item_nextsibling(@id, nxt)
      self
    else
      @tree.item_nextsibling(@id)
    end
  end
  alias next_sibling nextsibling

  def numchildren
    @tree.item_numchildren(@id)
  end
  alias num_children  numchildren
  alias children_size numchildren

  def parent_index
    @tree.item_parent(@id)
  end

  def prevsibling(nxt=nil)
    if nxt
      @tree.item_prevsibling(@id, nxt)
      self
    else
      @tree.item_prevsibling(@id)
    end
  end
  alias prev_sibling prevsibling

  def remove
    @tree.item_remove(@id)
  end

  def rnc
    @tree.item_rnc(@id)
  end

  def sort(*opts)
    @tree.item_sort(@id, *opts)
  end
  def sort_not_really(*opts)
    @tree.item_sort_not_really(@id, *opts)
    self
  end

  def state_forcolumn(column, *args)
    @tree.item_state_forcolumn(@id, column, *args)
    self
  end
  alias state_for_column state_forcolumn

  def state_get(*args)
    @tree.item_state_get(@id, *args)
  end

  def state_set(*args)
    @tree.item_state_set(@id, *args)
    self
  end

  def style_elements(column)
    @tree.item_style_elements(@id, column)
  end

  def style_map(column, style, map)
    @tree.item_style_map(@id, column, style, map)
    self
  end

  def style_set(column=nil, *args)
    if args.empty?
      @tree.item_style_set(@id, column)
    else
      @tree.item_style_set(@id, column, *args)
      self
    end
  end

  def item_text(column, txt=nil, *args)
    if args.empty?
      if txt
        @tree.item_text(@id, column, txt)
        self
      else
        @tree.item_text(@id, column)
      end
    else
      @tree.item_text(@id, column, txt, *args)
      self
    end
  end

  def toggle
    @tree.item_toggle(@id)
    self
  end

  def toggle_recurse
    @tree.item_toggle_recurse(@id)
    self
  end

  def visible(st=None)
    if st == None
      @tree.item_visible(@id)
    else
      @tree.item_visible(@id, st)
      self
    end
  end
end


class Tk::TreeCtrl::Style < TkObject
  TreeCtrlStyleID_TBL = TkCore::INTERP.create_table

  #nodyna <instance_eval-1642> <IEV MODERATE (method definition)>
  (TreeCtrlStyleID = ['treectrl_style'.freeze, TkUtil.untrust('00000')]).instance_eval{
    @mutex = Mutex.new
    def mutex; @mutex; end
    freeze
  }

  TkCore::INTERP.init_ip_env{
    Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.clear
    }
  }

  def self.id2obj(tree, id)
    tpath = tree.path
    Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.mutex.synchronize{
      if Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[tpath]
        Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[tpath][id]? \
                     Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[tpath][id] : id
      else
        id
      end
    }
  end

  def initialize(parent, keys=nil)
    @tree = parent
    @tpath = parent.path

    Tk::TreeCtrl::Style::TreeCtrlStyleID.mutex.synchronize{
      @path = @id =
        Tk::TreeCtrl::Style::TreeCtrlStyleID.join(TkCore::INTERP._ip_id_)
      Tk::TreeCtrl::Style::TreeCtrlStyleID[1].succ!
    }

    Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL.mutex.synchronize{
      Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[@tpath] ||= {}
      Tk::TreeCtrl::Style::TreeCtrlStyleID_TBL[@tpath][@id] = self
    }

    @tree.style_create(@id, keys)
  end

  def id
    @id
  end

  def to_s
    @id.dup
  end

  def cget_tkstring(opt)
    @tree.style_cget_tkstring(@id, opt)
  end
  def cget(opt)
    @tree.style_cget(@id, opt)
  end
  def cget_strict(opt)
    @tree.style_cget_strict(@id, opt)
  end

  def configure(*args)
    @tree.style_configure(@id, *args)
  end

  def configinfo(*args)
    @tree.style_configinfo(@id, *args)
  end

  def current_configinfo(*args)
    @tree.current_style_configinfo(@id, *args)
  end

  def delete
    @tree.style_delete(@id)
    self
  end

  def elements(*elems)
    if elems.empty?
      @tree.style_elements(@id)
    else
      @tree.style_elements(@id, *elems)
      self
    end
  end

  def layout(elem, keys=None)
    if keys && keys != None && keys.kind_of?(Hash)
      @tree.style_layout(@id, elem, keys)
      self
    else
      @tree.style_layout(@id, elem, keys)
    end
  end
end

module Tk::TreeCtrl::BindCallback
  include Tk
  extend Tk
end

class << Tk::TreeCtrl::BindCallback
  def percentsCmd(*args)
    tk_call('::TreeCtrl::PercentsCmd', *args)
  end
  def cursorCheck(w, x, y)
    tk_call('::TreeCtrl::CursorCheck', w, x, y)
  end
  def cursorCheckAux(w)
    tk_call('::TreeCtrl::CursorCheckAux', w)
  end
  def cursorCancel(w)
    tk_call('::TreeCtrl::CursorCancel', w)
  end
  def buttonPress1(w, x, y)
    tk_call('::TreeCtrl::ButtonPress1', w, x, y)
  end
  def doubleButton1(w, x, y)
    tk_call('::TreeCtrl::DoubleButton1', w, x, y)
  end
  def motion1(w, x, y)
    tk_call('::TreeCtrl::Motion1', w, x, y)
  end
  def leave1(w, x, y)
    tk_call('::TreeCtrl::Leave1', w, x, y)
  end
  def release1(w, x, y)
    tk_call('::TreeCtrl::Release1', w, x, y)
  end
  def beginSelect(w, el)
    tk_call('::TreeCtrl::BeginSelect', w, el)
  end
  def motion(w, le)
    tk_call('::TreeCtrl::Motion', w, el)
  end
  def beginExtend(w, el)
    tk_call('::TreeCtrl::BeginExtend', w, el)
  end
  def beginToggle(w, el)
    tk_call('::TreeCtrl::BeginToggle', w, el)
  end
  def cancelRepeat
    tk_call('::TreeCtrl::CancelRepeat')
  end
  def autoScanCheck(w, x, y)
    tk_call('::TreeCtrl::AutoScanCheck', w, x, y)
  end
  def autoScanCheckAux(w)
    tk_call('::TreeCtrl::AutoScanCheckAux', w)
  end
  def autoScanCancel(w)
    tk_call('::TreeCtrl::AutoScanCancel', w)
  end
  def up_down(w, n)
    tk_call('::TreeCtrl::UpDown', w, n)
  end
  def left_right(w, n)
    tk_call('::TreeCtrl::LeftRight', w, n)
  end
  def setActiveItem(w, idx)
    tk_call('::TreeCtrl::SetActiveItem', w, idx)
  end
  def extendUpDown(w, amount)
    tk_call('::TreeCtrl::ExtendUpDown', w, amount)
  end
  def dataExtend(w, el)
    tk_call('::TreeCtrl::DataExtend', w, el)
  end
  def cancel(w)
    tk_call('::TreeCtrl::Cancel', w)
  end
  def selectAll(w)
    tk_call('::TreeCtrl::selectAll', w)
  end
  def marqueeBegin(w, x, y)
    tk_call('::TreeCtrl::MarqueeBegin', w, x, y)
  end
  def marqueeUpdate(w, x, y)
    tk_call('::TreeCtrl::MarqueeUpdate', w, x, y)
  end
  def marqueeEnd(w, x, y)
    tk_call('::TreeCtrl::MarqueeEnd', w, x, y)
  end
  def scanMark(w, x, y)
    tk_call('::TreeCtrl::ScanMark', w, x, y)
  end
  def scanDrag(w, x, y)
    tk_call('::TreeCtrl::ScanDrag', w, x, y)
  end

  def fileList_button1(w, x, y)
    tk_call('::TreeCtrl::FileListButton1', w, x, y)
  end
  def fileList_motion1(w, x, y)
    tk_call('::TreeCtrl::FileListMotion1', w, x, y)
  end
  def fileList_motion(w, x, y)
    tk_call('::TreeCtrl::FileListMotion', w, x, y)
  end
  def fileList_leave1(w, x, y)
    tk_call('::TreeCtrl::FileListLeave1', w, x, y)
  end
  def fileList_release1(w, x, y)
    tk_call('::TreeCtrl::FileListRelease1', w, x, y)
  end
  def fileList_edit(w, i, s, e)
    tk_call('::TreeCtrl::FileListEdit', w, i, s, e)
  end
  def fileList_editCancel(w)
    tk_call('::TreeCtrl::FileListEditCancel', w)
  end
  def fileList_autoScanCheck(w, x, y)
    tk_call('::TreeCtrl::FileListAutoScanCheck', w, x, y)
  end
  def fileList_autoScanCheckAux(w)
    tk_call('::TreeCtrl::FileListAutoScanCheckAux', w)
  end

  def entryOpen(w, item, col, elem)
    tk_call('::TreeCtrl::EntryOpen', w, item, col, elem)
  end
  def entryExpanderOpen(w, item, col, elem)
    tk_call('::TreeCtrl::EntryExpanderOpen', w, item, col, elem)
  end
  def entryClose(w, accept)
    tk_call('::TreeCtrl::EntryClose', w, accept)
  end
  def entryExpanderKeypress(w)
    tk_call('::TreeCtrl::EntryExpanderKeypress', w)
  end
  def textOpen(w, item, col, elem, width=0, height=0)
    tk_call('::TreeCtrl::TextOpen', w, item, col, elem, width, height)
  end
  def textExpanderOpen(w, item, col, elem, width)
    tk_call('::TreeCtrl::TextOpen', w, item, col, elem, width)
  end
  def textClose(w, accept)
    tk_call('::TreeCtrl::TextClose', w, accept)
  end
  def textExpanderKeypress(w)
    tk_call('::TreeCtrl::TextExpanderKeypress', w)
  end
end
