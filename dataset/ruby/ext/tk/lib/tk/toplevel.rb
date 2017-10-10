require 'tk'
require 'tk/wm'
require 'tk/menuspec'

class Tk::Toplevel<TkWindow
  include Wm
  include TkMenuSpec

  TkCommandNames = ['toplevel'.freeze].freeze
  WidgetClassName = 'Toplevel'.freeze
  WidgetClassNames[WidgetClassName] ||= self


  def __boolval_optkeys
    super() << 'container'
  end
  private :__boolval_optkeys

  def __strval_optkeys
    super() << 'screen'
  end
  private :__strval_optkeys

  def __val2ruby_optkeys  # { key=>proc, ... }
    super().update('menu'=>proc{|v| window(v)})
  end
  private :__val2ruby_optkeys

  def __methodcall_optkeys  # { key=>method, ... }
    TOPLEVEL_METHODCALL_OPTKEYS
  end
  private :__methodcall_optkeys

  def _wm_command_option_chk(keys)
    keys = {} unless keys
    new_keys = {}
    wm_cmds = {}

    conf_methods = _symbolkey2str(__methodcall_optkeys())

    keys.each{|k,v| # k is a String
      if conf_methods.key?(k)
        wm_cmds[conf_methods[k]] = v
      elsif Wm.method_defined?(k)
        case k
        when 'screen','class','colormap','container','use','visual'
          new_keys[k] = v
        else
          case self.method(k).arity
          when -1,1
            wm_cmds[k] = v
          else
            new_keys[k] = v
          end
        end
      else
        new_keys[k] = v
      end
    }
    [new_keys, wm_cmds]
  end
  private :_wm_command_option_chk

  def initialize(parent=nil, screen=nil, classname=nil, keys=nil)
    my_class_name = nil
    if self.class < WidgetClassNames[WidgetClassName]
      my_class_name = self.class.name
      my_class_name = nil if my_class_name == ''
    end
    if parent.kind_of? Hash
      keys = _symbolkey2str(parent)
      if keys.key?('classname')
        keys['class'] = keys.delete('classname')
      end
      @classname = keys['class']
      @colormap  = keys['colormap']
      @container = keys['container']
      @screen    = keys['screen']
      @use       = keys['use']
      @visual    = keys['visual']
      if !@classname && my_class_name
        keys['class'] = @classname = my_class_name
      end
      if @classname.kind_of? TkBindTag
        @db_class = @classname
        keys['class'] = @classname = @classname.id
      elsif @classname
        @db_class = TkDatabaseClass.new(@classname)
        keys['class'] = @classname
      else
        @db_class = self.class
        @classname = @db_class::WidgetClassName
      end
      keys, cmds = _wm_command_option_chk(keys)
      super(keys)
      cmds.each{|k,v|
        if v.kind_of? Array
          self.__send__(k,*v)
        else
          self.__send__(k,v)
        end
      }
      return
    end

    if screen.kind_of? Hash
      keys = screen
    else
      @screen = screen
      if classname.kind_of? Hash
        keys = classname
      else
        @classname = classname
      end
    end
    if keys.kind_of? Hash
      keys = _symbolkey2str(keys)
      if keys.key?('classname')
        keys['class'] = keys.delete('classname')
      end
      @classname = keys['class']  unless @classname
      @colormap  = keys['colormap']
      @container = keys['container']
      @screen    = keys['screen'] unless @screen
      @use       = keys['use']
      @visual    = keys['visual']
    else
      keys = {}
    end
    if !@classname && my_class_name
      keys['class'] = @classname = my_class_name
    end
    if @classname.kind_of? TkBindTag
      @db_class = @classname
      keys['class'] = @classname = @classname.id
    elsif @classname
      @db_class = TkDatabaseClass.new(@classname)
      keys['class'] = @classname
    else
      @db_class = self.class
      @classname = @db_class::WidgetClassName
    end
    keys, cmds = _wm_command_option_chk(keys)
    super(parent, keys)
    cmds.each{|k,v|
      if v.kind_of? Array
        #nodyna <send-1838> <SD COMPLEX (change-prone variables)>
        self.send(k,*v)
      else
        #nodyna <send-1839> <SD COMPLEX (change-prone variables)>
        self.send(k,v)
      end
    }
  end


  def specific_class
    @classname
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

  def self.database_class
    if self == WidgetClassNames[WidgetClassName] || self.name == ''
      self
    else
      TkDatabaseClass.new(self.name)
    end
  end
  def self.database_classname
    self.database_class.name
  end

  def self.bind(*args, &b)
    if self == WidgetClassNames[WidgetClassName] || self.name == ''
      super(*args, &b)
    else
      TkDatabaseClass.new(self.name).bind(*args, &b)
    end
  end
  def self.bind_append(*args, &b)
    if self == WidgetClassNames[WidgetClassName] || self.name == ''
      super(*args, &b)
    else
      TkDatabaseClass.new(self.name).bind_append(*args, &b)
    end
  end
  def self.bind_remove(*args)
    if self == WidgetClassNames[WidgetClassName] || self.name == ''
      super(*args)
    else
      TkDatabaseClass.new(self.name).bind_remove(*args)
    end
  end
  def self.bindinfo(*args)
    if self == WidgetClassNames[WidgetClassName] || self.name == ''
      super(*args)
    else
      TkDatabaseClass.new(self.name).bindinfo(*args)
    end
  end
end

Tk.__set_loaded_toplevel_aliases__('tk/toplevel.rb', :Tk, Tk::Toplevel,
                                   :TkToplevel)
