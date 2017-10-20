require 'tk'

class TkMsgCatalog < TkObject
  include TkCore
  extend Tk

  TkCommandNames = [
    '::msgcat::mc'.freeze,
    '::msgcat::mcmax'.freeze,
    '::msgcat::mclocale'.freeze,
    '::msgcat::mcpreferences'.freeze,
    '::msgcat::mcload'.freeze,
    '::msgcat::mcset'.freeze,
    '::msgcat::mcmset'.freeze,
    '::msgcat::mcunknown'.freeze
  ].freeze

  tk_call_without_enc('package', 'require', 'Tcl', '8.2')

  PACKAGE_NAME = 'msgcat'.freeze
  def self.package_name
    PACKAGE_NAME
  end

  if self.const_defined? :FORCE_VERSION
    tk_call_without_enc('package', 'require', 'msgcat', FORCE_VERSION)
  else
    tk_call_without_enc('package', 'require', 'msgcat')
  end

  MSGCAT_EXT = '.msg'

  UNKNOWN_CBTBL = TkUtil.untrust(Hash.new{|hash,key| hash[key] = {}})

  TkCore::INTERP.add_tk_procs('::msgcat::mcunknown', 'args', <<-'EOL')
    #nodyna <eval-1786> <EV COMPLEX (change-prone variables)>
    if {[set st [catch {eval {ruby_cmd TkMsgCatalog callback} [namespace current] $args} ret]] != 0} {
       set idx [string first "\n\n" $ret]
       if {$idx > 0} {
          return -code $st \
                 -errorinfo [string range $ret [expr $idx + 2] \
                                               [string length $ret]] \
                 [string range $ret 0 [expr $idx - 1]]
       } else {
          return -code $st $ret
       }
    } else {
        return $ret
    }
  EOL

  def self.callback(namespace, locale, src_str, *args)
    src_str = sprintf(src_str, *args) unless args.empty?
    cmd_tbl = TkMsgCatalog::UNKNOWN_CBTBL[TkCore::INTERP.__getip]
    cmd = cmd_tbl[namespace]
    cmd = cmd_tbl['::'] unless cmd  # use global scope as interp default
    return src_str unless cmd       # no cmd -> return src-str (default action)
    begin
      cmd.call(locale, src_str)
    rescue SystemExit
      exit(0)
    rescue Interrupt
      exit!(1)
    rescue Exception => e
      begin
        msg = _toUTF8(e.class.inspect) + ': ' +
              _toUTF8(e.message) + "\n" +
              "\n---< backtrace of Ruby side >-----\n" +
              _toUTF8(e.backtrace.join("\n")) +
              "\n---< backtrace of Tk side >-------"
        if TkCore::WITH_ENCODING
          msg.force_encoding('utf-8')
        else
          #nodyna <instance_variable_set-1787> <IVS MODERATE (private access)>
          msg.instance_variable_set(:@encoding, 'utf-8')
        end
      rescue Exception
        msg = e.class.inspect + ': ' + e.message + "\n" +
              "\n---< backtrace of Ruby side >-----\n" +
              e.backtrace.join("\n") +
              "\n---< backtrace of Tk side >-------"
      end
      fail(e, msg)
    end
  end

  def initialize(namespace = nil)
    if namespace.kind_of?(TkNamespace)
      @namespace = namespace
    elsif namespace == nil
      @namespace = TkNamespace.new('::')  # global namespace
    else
      @namespace = TkNamespace.new(namespace)
    end
    @path = @namespace.path

    @msgcat_ext = '.msg'
  end
  attr_accessor :msgcat_ext

  def method_missing(id, *args)
    loc = id.id2name
    case args.length
    when 0 # set locale
      self.locale=(loc)

    when 1 # src only, or trans_list
      if args[0].kind_of?(Array)
        self.set_translation_list(loc, args[0])
      else
        self.set_translation(loc, args[0])
      end

    when 2 # src and trans, or, trans_list and enc
      if args[0].kind_of?(Array)
        self.set_translation_list(loc, *args)
      else
        self.set_translation(loc, *args)
      end

    when 3 # src and trans and enc
      self.set_translation(loc, *args)

    else
      super(id, *args)

    end
  end

  def self.translate(*args)
    dst = args.collect{|src|
      tk_call_without_enc('::msgcat::mc', _get_eval_string(src, true))
    }
    Tk.UTF8_String(sprintf(*dst))
  end
  class << self
    alias mc translate
    alias [] translate
  end
  def translate(*args)
    dst = args.collect{|src|
      #nodyna <eval-1788> <EV COMPLEX (change-prone variables)>
      @namespace.eval{tk_call_without_enc('::msgcat::mc',
                                          _get_eval_string(src, true))}
    }
    Tk.UTF8_String(sprintf(*dst))
  end
  alias mc translate
  alias [] translate

  def self.maxlen(*src_strings)
    tk_call('::msgcat::mcmax', *src_strings).to_i
  end
  def maxlen(*src_strings)
    #nodyna <eval-1789> <EV COMPLEX (change-prone variables)>
    @namespace.eval{tk_call('::msgcat::mcmax', *src_strings).to_i}
  end

  def self.locale
    tk_call('::msgcat::mclocale')
  end
  def locale
    #nodyna <eval-1790> <EV COMPLEX (change-prone variables)>
    @namespace.eval{tk_call('::msgcat::mclocale')}
  end

  def self.locale=(locale)
    tk_call('::msgcat::mclocale', locale)
  end
  def locale=(locale)
    #nodyna <eval-1791> <EV COMPLEX (change-prone variables)>
    @namespace.eval{tk_call('::msgcat::mclocale', locale)}
  end

  def self.preferences
    tk_split_simplelist(tk_call('::msgcat::mcpreferences'))
  end
  def preferences
    #nodyna <eval-1792> <EV COMPLEX (change-prone variables)>
    tk_split_simplelist(@namespace.eval{tk_call('::msgcat::mcpreferences')})
  end

  def self.load_tk(dir)
    number(tk_call('::msgcat::mcload', dir))
  end

  def self.load_rb(dir)
    count = 0
    preferences().each{|loc|
      file = File.join(dir, loc + self::MSGCAT_EXT)
      if File.readable?(file)
        count += 1
        if TkCore::WITH_ENCODING
          #nodyna <eval-1793> <EV COMPLEX (change-prone variables)>
          eval(IO.read(file, :encoding=>"ASCII-8BIT"))
        else
          #nodyna <eval-1794> <EV COMPLEX (change-prone variables)>
          eval(IO.read(file))
        end
      end
    }
    count
  end

  def load_tk(dir)
    #nodyna <eval-1795> <EV COMPLEX (change-prone variables)>
    number(@namespace.eval{tk_call('::msgcat::mcload', dir)})
  end

  def load_rb(dir)
    count = 0
    preferences().each{|loc|
      file = File.join(dir, loc + @msgcat_ext)
      if File.readable?(file)
        count += 1
        if TkCore::WITH_ENCODING
          #nodyna <eval-1796> <EV COMPLEX (change-prone variables)>
          @namespace.eval(IO.read(file, :encoding=>"ASCII-8BIT"))
        else
          #nodyna <eval-1797> <EV COMPLEX (change-prone variables)>
          @namespace.eval(IO.read(file))
        end
      end
    }
    count
  end

  def self.load(dir)
    self.load_rb(dir)
  end
  alias load load_rb

  def self.set_translation(locale, src_str, trans_str=None, enc='utf-8')
    if trans_str && trans_str != None
      trans_str = Tk.UTF8_String(_toUTF8(trans_str, enc))
      Tk.UTF8_String(ip_eval_without_enc("::msgcat::mcset {#{locale}} {#{_get_eval_string(src_str, true)}} {#{trans_str}}"))
    else
      Tk.UTF8_String(ip_eval_without_enc("::msgcat::mcset {#{locale}} {#{_get_eval_string(src_str, true)}}"))
    end
  end
  def set_translation(locale, src_str, trans_str=None, enc='utf-8')
    if trans_str && trans_str != None
      trans_str = Tk.UTF8_String(_toUTF8(trans_str, enc))
      #nodyna <eval-1798> <EV COMPLEX (change-prone variables)>
      Tk.UTF8_String(@namespace.eval{
                       ip_eval_without_enc("::msgcat::mcset {#{locale}} {#{_get_eval_string(src_str, true)}} {#{trans_str}}")
                     })
    else
      #nodyna <eval-1799> <EV COMPLEX (change-prone variables)>
      Tk.UTF8_String(@namespace.eval{
                       ip_eval_without_enc("::msgcat::mcset {#{locale}} {#{_get_eval_string(src_str, true)}}")
                     })
    end
  end

  def self.set_translation_list(locale, trans_list, enc='utf-8')
    list = []
    trans_list.each{|src, trans|
      if trans && trans != None
        list << _get_eval_string(src, true)
        list << Tk.UTF8_String(_toUTF8(trans, enc))
      else
        list << _get_eval_string(src, true) << ''
      end
    }
    number(ip_eval_without_enc("::msgcat::mcmset {#{locale}} {#{_get_eval_string(list)}}"))
  end
  def set_translation_list(locale, trans_list, enc='utf-8')
    list = []
    trans_list.each{|src, trans|
      if trans && trans != None
        list << _get_eval_string(src, true)
        list << Tk.UTF8_String(_toUTF8(trans, enc))
      else
        list << _get_eval_string(src, true) << ''
      end
    }
    #nodyna <eval-1800> <EV COMPLEX (change-prone variables)>
    number(@namespace.eval{
             ip_eval_without_enc("::msgcat::mcmset {#{locale}} {#{_get_eval_string(list)}}")
           })
  end

  def self.def_unknown_proc(cmd=Proc.new)
    TkMsgCatalog::UNKNOWN_CBTBL[TkCore::INTERP.__getip]['::'] = cmd
  end
  def def_unknown_proc(cmd=Proc.new)
    TkMsgCatalog::UNKNOWN_CBTBL[TkCore::INTERP.__getip][@namespace.path] = cmd
  end
end

TkMsgCat = TkMsgCatalog
