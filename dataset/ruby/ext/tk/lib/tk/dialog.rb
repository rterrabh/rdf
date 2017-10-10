require 'tk'
require 'tk/variable.rb'

class TkDialogObj < TkWindow
  extend Tk

  TkCommandNames = ['tk_dialog'.freeze].freeze

  def self.show(*args)
    dlog = self.new(*args)
    dlog.show
    dlog
  end

  def _set_button_config(configs)
    set_config = proc{|c,i|
      if $VERBOSE && (c.has_key?('command') || c.has_key?(:command))
        STDERR.print("Warning: cannot give a command option " +
                     "to the dialog button#{i}. It was removed.\n")
      end
      c.delete('command'); c.delete(:command)
      @config << @path+'.button'+i.to_s+' configure '+
                   array2tk_list(hash_kv(c))+'; '
    }
    case configs
    when Proc
      @buttons.each_index{|i|
        if (c = configs.call(i)).kind_of?(Hash)
          set_config.call(c,i)
        end
      }

    when Array
      @buttons.each_index{|i|
        if (c = configs[i]).kind_of?(Hash)
          set_config.call(c,i)
        end
      }

    when Hash
      @buttons.each_with_index{|s,i|
        if (c = configs[s]).kind_of?(Hash)
          set_config.call(c,i)
        end
      }
    end
    @config = array2tk_list(['after', 'idle', @config]) << ';' if @config != ""
  end
  private :_set_button_config

  def create_self(keys)
    @val = nil

    @title   = title

    @message = message
    @message_config = message_config
    @msgframe_config = msgframe_config

    @bitmap  = bitmap
    @bitmap_config = message_config

    @default_button = default_button

    @buttons = buttons
    @button_configs = proc{|num| button_configs(num)}
    @btnframe_config = btnframe_config

    @config = ""

    @command = prev_command

    if keys.kind_of?(Hash)
      @title   = keys['title'] if keys.key? 'title'
      @message = keys['message'] if keys.key? 'message'
      @bitmap  = keys['bitmap'] if keys.key? 'bitmap'
      @bitmap  = '' unless @bitmap
      @default_button = keys['default'] if keys.key? 'default'
      @buttons = keys['buttons'] if keys.key? 'buttons'

      @command = keys['prev_command'] if keys.key? 'prev_command'

      @message_config = keys['message_config'] if keys.key? 'message_config'
      @msgframe_config = keys['msgframe_config'] if keys.key? 'msgframe_config'
      @bitmap_config  = keys['bitmap_config']  if keys.key? 'bitmap_config'
      @button_configs = keys['button_configs'] if keys.key? 'button_configs'
      @btnframe_config = keys['btnframe_config'] if keys.key? 'btnframe_config'
    end


    if @buttons.kind_of?(Array)
      _set_button_config(@buttons.collect{|cfg|
                           (cfg.kind_of? Array)? cfg[1]: nil})
      @buttons = @buttons.collect{|cfg| (cfg.kind_of? Array)? cfg[0]: cfg}
    end
    if @buttons.kind_of?(Hash)
      _set_button_config(@buttons)
      @buttons = @buttons.keys
    end
    @buttons = tk_split_simplelist(@buttons) if @buttons.kind_of?(String)
    @buttons = [] unless @buttons
=begin
    @buttons = @buttons.collect{|s|
      if s.kind_of?(Array)
        s = s.join(' ')
      end
      if s.include? ?\s
        '{' + s + '}'
      else
        s
      end
    }
=end

    if @message_config.kind_of?(Hash)
      @config << @path+'.msg configure '+
                   array2tk_list(hash_kv(@message_config))+';'
    end

    if @msgframe_config.kind_of?(Hash)
      @config << @path+'.top configure '+
                   array2tk_list(hash_kv(@msgframe_config))+';'
    end

    if @btnframe_config.kind_of?(Hash)
      @config << @path+'.bot configure '+
                   array2tk_list(hash_kv(@btnframe_config))+';'
    end

    if @bitmap_config.kind_of?(Hash)
      @config << @path+'.bitmap configure '+
                    array2tk_list(hash_kv(@bitmap_config))+';'
    end

    _set_button_config(@button_configs) if @button_configs
  end
  private :create_self

  def show
    if TkComm._callback_entry?(@command)
      @command.call(self)
    end

    if @default_button.kind_of?(String)
      default_button = @buttons.index(@default_button)
    else
      default_button = @default_button
    end
    default_button = '' if default_button == nil
    Tk.ip_eval(@config)
    @val = Tk.ip_eval(array2tk_list([
                                      self.class::TkCommandNames[0],
                                      @path, @title, @message, @bitmap,
                                      String(default_button)
                                    ].concat(@buttons))).to_i
  end

  def value
    @val
  end

  def name
    (@val)? @buttons[@val]: nil
  end

  private

  def title
    return "DIALOG"
  end
  def message
    return "MESSAGE"
  end
  def message_config
    return nil
  end
  def msgframe_config
    return nil
  end
  def bitmap
    return "info"
  end
  def bitmap_config
    return nil
  end
  def default_button
    return 0
  end
  def buttons
    return ["BUTTON1", "BUTTON2"]
  end
  def button_configs(num)
    return nil
  end
  def btnframe_config
    return nil
  end
  def prev_command
    return nil
  end
end
TkDialog2 = TkDialogObj

class TkDialog < TkDialogObj
  def self.show(*args)
    self.new(*args)
  end

  def initialize(*args)
    super(*args)
    show
  end
end


class TkWarningObj < TkDialogObj
  def initialize(parent = nil, mes = nil)
    if !mes
      if parent.kind_of?(TkWindow)
        mes = ""
      else
        mes = parent.to_s
        parent = nil
      end
    end
    super(parent, :message=>mes)
  end

  def show(mes = nil)
    mes_bup = @message
    @message = mes if mes
    ret = super()
    @message = mes_bup
    ret
  end

  private

  def title
    return "WARNING";
  end
  def bitmap
    return "warning";
  end
  def default_button
    return 0;
  end
  def buttons
    return "OK";
  end
end
TkWarning2 = TkWarningObj

class TkWarning < TkWarningObj
  def self.show(*args)
    self.new(*args)
  end
  def initialize(*args)
    super(*args)
    show
  end
end
