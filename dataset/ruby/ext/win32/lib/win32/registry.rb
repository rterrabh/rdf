require 'win32/importer'

module Win32

=begin rdoc
= Win32 Registry

win32/registry is registry accessor library for Win32 platform.
It uses importer to call Win32 Registry APIs.

== example
  Win32::Registry::HKEY_CURRENT_USER.open('SOFTWARE\foo') do |reg|
    value = reg['foo']                               # read a value
    value = reg['foo', Win32::Registry::REG_SZ]      # read a value with type
    type, value = reg.read('foo')                    # read a value
    reg['foo'] = 'bar'                               # write a value
    reg['foo', Win32::Registry::REG_SZ] = 'bar'      # write a value with type
    reg.write('foo', Win32::Registry::REG_SZ, 'bar') # write a value

    reg.each_value { |name, type, data| ... }        # Enumerate values
    reg.each_key { |key, wtime| ... }                # Enumerate subkeys

    reg.delete_value(name)                         # Delete a value
    reg.delete_key(name)                           # Delete a subkey
    reg.delete_key(name, true)                     # Delete a subkey recursively
  end

= Reference

== Win32::Registry class

--- info

--- num_keys

--- max_key_length

--- num_values

--- max_value_name_length

--- max_value_length

--- descriptor_length

--- wtime
    Returns an item of key information.

=== constants
--- HKEY_CLASSES_ROOT

--- HKEY_CURRENT_USER

--- HKEY_LOCAL_MACHINE

--- HKEY_PERFORMANCE_DATA

--- HKEY_CURRENT_CONFIG

--- HKEY_DYN_DATA

    Win32::Registry object whose key is predefined key.
For detail, see the MSDN[http://msdn.microsoft.com/library/en-us/sysinfo/base/predefined_keys.asp] article.

=end rdoc

  WCHAR = Encoding::UTF_16LE
  WCHAR_NUL = "\0".encode(WCHAR).freeze
  WCHAR_CR = "\r".encode(WCHAR).freeze
  WCHAR_SIZE = WCHAR_NUL.bytesize
  LOCALE = Encoding.find(Encoding.locale_charmap)

  class Registry

    module Constants
      HKEY_CLASSES_ROOT = 0x80000000
      HKEY_CURRENT_USER = 0x80000001
      HKEY_LOCAL_MACHINE = 0x80000002
      HKEY_USERS = 0x80000003
      HKEY_PERFORMANCE_DATA = 0x80000004
      HKEY_PERFORMANCE_TEXT = 0x80000050
      HKEY_PERFORMANCE_NLSTEXT = 0x80000060
      HKEY_CURRENT_CONFIG = 0x80000005
      HKEY_DYN_DATA = 0x80000006

      REG_NONE = 0
      REG_SZ = 1
      REG_EXPAND_SZ = 2
      REG_BINARY = 3
      REG_DWORD = 4
      REG_DWORD_LITTLE_ENDIAN = 4
      REG_DWORD_BIG_ENDIAN = 5
      REG_LINK = 6
      REG_MULTI_SZ = 7
      REG_RESOURCE_LIST = 8
      REG_FULL_RESOURCE_DESCRIPTOR = 9
      REG_RESOURCE_REQUIREMENTS_LIST = 10
      REG_QWORD = 11
      REG_QWORD_LITTLE_ENDIAN = 11

      STANDARD_RIGHTS_READ = 0x00020000
      STANDARD_RIGHTS_WRITE = 0x00020000
      KEY_QUERY_VALUE = 0x0001
      KEY_SET_VALUE = 0x0002
      KEY_CREATE_SUB_KEY = 0x0004
      KEY_ENUMERATE_SUB_KEYS = 0x0008
      KEY_NOTIFY = 0x0010
      KEY_CREATE_LINK = 0x0020
      KEY_READ = STANDARD_RIGHTS_READ |
        KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY
      KEY_WRITE = STANDARD_RIGHTS_WRITE |
        KEY_SET_VALUE | KEY_CREATE_SUB_KEY
      KEY_EXECUTE = KEY_READ
      KEY_ALL_ACCESS = KEY_READ | KEY_WRITE | KEY_CREATE_LINK

      REG_OPTION_RESERVED = 0x0000
      REG_OPTION_NON_VOLATILE = 0x0000
      REG_OPTION_VOLATILE = 0x0001
      REG_OPTION_CREATE_LINK = 0x0002
      REG_OPTION_BACKUP_RESTORE = 0x0004
      REG_OPTION_OPEN_LINK = 0x0008
      REG_LEGAL_OPTION = REG_OPTION_RESERVED |
        REG_OPTION_NON_VOLATILE | REG_OPTION_CREATE_LINK |
        REG_OPTION_BACKUP_RESTORE | REG_OPTION_OPEN_LINK

      REG_CREATED_NEW_KEY = 1
      REG_OPENED_EXISTING_KEY = 2

      REG_WHOLE_HIVE_VOLATILE = 0x0001
      REG_REFRESH_HIVE = 0x0002
      REG_NO_LAZY_FLUSH = 0x0004
      REG_FORCE_RESTORE = 0x0008

      MAX_KEY_LENGTH = 514
      MAX_VALUE_LENGTH = 32768
    end
    include Constants
    include Enumerable

    class Error < ::StandardError
      module Kernel32
        extend Importer
        dlload "kernel32.dll"
      end
      FormatMessageW = Kernel32.extern "int FormatMessageW(int, void *, int, int, void *, int, void *)", :stdcall
      def initialize(code)
        @code = code
        buff = WCHAR_NUL * 1024
        lang = 0
        begin
          len = FormatMessageW.call(0x1200, 0, code, lang, buff, 1024, 0)
          msg = buff.byteslice(0, len * WCHAR_SIZE)
          msg.delete!(WCHAR_CR)
          msg.chomp!
          msg.encode!(LOCALE)
        rescue EncodingError
          raise unless lang == 0
          lang = 0x0409         # en_US
          retry
        end
        super msg
      end
      attr_reader :code
    end

    class PredefinedKey < Registry
      def initialize(hkey, keyname)
        @hkey = hkey
        @parent = nil
        @keyname = keyname
        @disposition = REG_OPENED_EXISTING_KEY
      end

      def close
        raise Error.new(5) ## ERROR_ACCESS_DENIED
      end

      def class
        Registry
      end

      Constants.constants.grep(/^HKEY_/) do |c|
        #nodyna <const_get-1513> <CG COMPLEX (array)>
        #nodyna <const_set-1514> <CS COMPLEX (change-prone variable)>
        Registry.const_set c, new(Constants.const_get(c), c.to_s)
      end
    end

    module API
      include Constants
      extend Importer
      dlload "advapi32.dll"
      [
        "long RegOpenKeyExW(void *, void *, long, long, void *)",
        "long RegCreateKeyExW(void *, void *, long, long, long, long, void *, void *, void *)",
        "long RegEnumValueW(void *, long, void *, void *, void *, void *, void *, void *)",
        "long RegEnumKeyExW(void *, long, void *, void *, void *, void *, void *, void *)",
        "long RegQueryValueExW(void *, void *, void *, void *, void *, void *)",
        "long RegSetValueExW(void *, void *, long, long, void *, long)",
        "long RegDeleteValueW(void *, void *)",
        "long RegDeleteKeyW(void *, void *)",
        "long RegFlushKey(void *)",
        "long RegCloseKey(void *)",
        "long RegQueryInfoKey(void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *, void *)",
      ].each do |fn|
        cfunc = extern fn, :stdcall
        #nodyna <const_set-1515> <CS MODERATE (array)>
        const_set cfunc.name.intern, cfunc
      end

      module_function

      def check(result)
        raise Error, result, caller(1) if result != 0
      end

      def win64?
        /^(?:x64|x86_64)/ =~ RUBY_PLATFORM
      end

      def packhandle(h)
        win64? ? packqw(h) : packdw(h)
      end

      def unpackhandle(h)
        win64? ? unpackqw(h) : unpackdw(h)
      end

      def packdw(dw)
        [dw].pack('V')
      end

      def unpackdw(dw)
        dw += [0].pack('V')
        dw.unpack('V')[0]
      end

      def packqw(qw)
        [ qw & 0xFFFFFFFF, qw >> 32 ].pack('VV')
      end

      def unpackqw(qw)
        qw = qw.unpack('VV')
        (qw[1] << 32) | qw[0]
      end

      def make_wstr(str)
        str.encode(WCHAR)
      end

      def OpenKey(hkey, name, opt, desired)
        result = packhandle(0)
        check RegOpenKeyExW.call(hkey, make_wstr(name), opt, desired, result)
        unpackhandle(result)
      end

      def CreateKey(hkey, name, opt, desired)
        result = packhandle(0)
        disp = packdw(0)
        check RegCreateKeyExW.call(hkey, make_wstr(name), 0, 0, opt, desired,
                                   0, result, disp)
        [ unpackhandle(result), unpackdw(disp) ]
      end

      def EnumValue(hkey, index)
        name = WCHAR_NUL * Constants::MAX_KEY_LENGTH
        size = packdw(Constants::MAX_KEY_LENGTH)
        check RegEnumValueW.call(hkey, index, name, size, 0, 0, 0, 0)
        name.byteslice(0, unpackdw(size) * WCHAR_SIZE)
      end

      def EnumKey(hkey, index)
        name = WCHAR_NUL * Constants::MAX_KEY_LENGTH
        size = packdw(Constants::MAX_KEY_LENGTH)
        wtime = ' ' * 8
        check RegEnumKeyExW.call(hkey, index, name, size, 0, 0, 0, wtime)
        [ name.byteslice(0, unpackdw(size) * WCHAR_SIZE), unpackqw(wtime) ]
      end

      def QueryValue(hkey, name)
        type = packdw(0)
        size = packdw(0)
        name = make_wstr(name)
        check RegQueryValueExW.call(hkey, name, 0, type, 0, size)
        data = "\0".force_encoding('ASCII-8BIT') * unpackdw(size)
        check RegQueryValueExW.call(hkey, name, 0, type, data, size)
        [ unpackdw(type), data[0, unpackdw(size)] ]
      end

      def SetValue(hkey, name, type, data, size)
        case type
        when REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ
          data = data.encode(WCHAR)
          size ||= data.bytesize + WCHAR_SIZE
        end
        check RegSetValueExW.call(hkey, make_wstr(name), 0, type, data, size)
      end

      def DeleteValue(hkey, name)
        check RegDeleteValue.call(hkey, make_wstr(name))
      end

      def DeleteKey(hkey, name)
        check RegDeleteKey.call(hkey, make_wstr(name))
      end

      def FlushKey(hkey)
        check RegFlushKey.call(hkey)
      end

      def CloseKey(hkey)
        check RegCloseKey.call(hkey)
      end

      def QueryInfoKey(hkey)
        subkeys = packdw(0)
        maxsubkeylen = packdw(0)
        values = packdw(0)
        maxvaluenamelen = packdw(0)
        maxvaluelen = packdw(0)
        secdescs = packdw(0)
        wtime = ' ' * 8
        check RegQueryInfoKey.call(hkey, 0, 0, 0, subkeys, maxsubkeylen, 0,
          values, maxvaluenamelen, maxvaluelen, secdescs, wtime)
        [ unpackdw(subkeys), unpackdw(maxsubkeylen), unpackdw(values),
          unpackdw(maxvaluenamelen), unpackdw(maxvaluelen),
          unpackdw(secdescs), unpackqw(wtime) ]
      end
    end

    def self.expand_environ(str)
      str.gsub(Regexp.compile("%([^%]+)%".encode(str.encoding))) {
        v = $1.encode(LOCALE)
        (e = ENV[v] || ENV[v.upcase]; e.encode(str.encoding) if e) ||
        $&
      }
    end

    @@type2name = { }
    %w[
      REG_NONE REG_SZ REG_EXPAND_SZ REG_BINARY REG_DWORD
      REG_DWORD_BIG_ENDIAN REG_LINK REG_MULTI_SZ
      REG_RESOURCE_LIST REG_FULL_RESOURCE_DESCRIPTOR
      REG_RESOURCE_REQUIREMENTS_LIST REG_QWORD
    ].each do |type|
      #nodyna <const_get-1516> <CG MODERATE (array)>
      @@type2name[Constants.const_get(type)] = type
    end

    def self.type2name(type)
      @@type2name[type] || type.to_s
    end

    def self.wtime2time(wtime)
      Time.at((wtime - 116444736000000000) / 10000000)
    end

    def self.time2wtime(time)
      time.to_i * 10000000 + 116444736000000000
    end

    private_class_method :new

    def self.open(hkey, subkey, desired = KEY_READ, opt = REG_OPTION_RESERVED)
      subkey = subkey.chomp('\\')
      newkey = API.OpenKey(hkey.hkey, subkey, opt, desired)
      obj = new(newkey, hkey, subkey, REG_OPENED_EXISTING_KEY)
      if block_given?
        begin
          yield obj
        ensure
          obj.close
        end
      else
        obj
      end
    end

    def self.create(hkey, subkey, desired = KEY_ALL_ACCESS, opt = REG_OPTION_RESERVED)
      newkey, disp = API.CreateKey(hkey.hkey, subkey, opt, desired)
      obj = new(newkey, hkey, subkey, disp)
      if block_given?
        begin
          yield obj
        ensure
          obj.close
        end
      else
        obj
      end
    end

    @@final = proc { |hkey| proc { API.CloseKey(hkey[0]) if hkey[0] } }

    def initialize(hkey, parent, keyname, disposition)
      @hkey = hkey
      @parent = parent
      @keyname = keyname
      @disposition = disposition
      @hkeyfinal = [ hkey ]
      ObjectSpace.define_finalizer self, @@final.call(@hkeyfinal)
    end

    attr_reader :hkey
    attr_reader :parent
    attr_reader :keyname
    attr_reader :disposition

    def created?
      @disposition == REG_CREATED_NEW_KEY
    end

    def open?
      !@hkey.nil?
    end

    def name
      parent = self
      name = @keyname
      while parent = parent.parent
        name = parent.keyname + '\\' + name
      end
      name
    end

    def inspect
      "\#<Win32::Registry key=#{name.inspect}>"
    end

    def _dump(depth)
      raise TypeError, "can't dump Win32::Registry"
    end

    def open(subkey, desired = KEY_READ, opt = REG_OPTION_RESERVED, &blk)
      self.class.open(self, subkey, desired, opt, &blk)
    end

    def create(subkey, desired = KEY_ALL_ACCESS, opt = REG_OPTION_RESERVED, &blk)
      self.class.create(self, subkey, desired, opt, &blk)
    end

    def close
      API.CloseKey(@hkey)
      @hkey = @parent = @keyname = nil
      @hkeyfinal[0] = nil
    end

    def each_value
      index = 0
      while true
        begin
          subkey = API.EnumValue(@hkey, index)
        rescue Error
          break
        end
        subkey = export_string(subkey)
        begin
          type, data = read(subkey)
        rescue Error
          next
        end
        yield subkey, type, data
        index += 1
      end
      index
    end
    alias each each_value

    def values
      vals_ary = []
      each_value { |*, val| vals_ary << val }
      vals_ary
    end

    def each_key
      index = 0
      while true
        begin
          subkey, wtime = API.EnumKey(@hkey, index)
        rescue Error
          break
        end
        subkey = export_string(subkey)
        yield subkey, wtime
        index += 1
      end
      index
    end

    def keys
      keys_ary = []
      each_key { |key,| keys_ary << key }
      keys_ary
    end

    def read(name, *rtype)
      type, data = API.QueryValue(@hkey, name)
      unless rtype.empty? or rtype.include?(type)
        raise TypeError, "Type mismatch (expect #{rtype.inspect} but #{type} present)"
      end
      case type
      when REG_SZ, REG_EXPAND_SZ
        [ type, data.encode(name.encoding, WCHAR).chop ]
      when REG_MULTI_SZ
        [ type, data.encode(name.encoding, WCHAR).split(/\0/) ]
      when REG_BINARY
        [ type, data ]
      when REG_DWORD
        [ type, API.unpackdw(data) ]
      when REG_DWORD_BIG_ENDIAN
        [ type, data.unpack('N')[0] ]
      when REG_QWORD
        [ type, API.unpackqw(data) ]
      else
        raise TypeError, "Type #{type} is not supported."
      end
    end

    def [](name, *rtype)
      type, data = read(name, *rtype)
      case type
      when REG_SZ, REG_DWORD, REG_QWORD, REG_MULTI_SZ
        data
      when REG_EXPAND_SZ
        Registry.expand_environ(data)
      else
        raise TypeError, "Type #{type} is not supported."
      end
    end

    def read_s(name)
      read(name, REG_SZ)[1]
    end

    def read_s_expand(name)
      type, data = read(name, REG_SZ, REG_EXPAND_SZ)
      if type == REG_EXPAND_SZ
        Registry.expand_environ(data)
      else
        data
      end
    end

    def read_i(name)
      read(name, REG_DWORD, REG_DWORD_BIG_ENDIAN, REG_QWORD)[1]
    end

    def read_bin(name)
      read(name, REG_BINARY)[1]
    end

    def write(name, type, data)
      termsize = 0
      case type
      when REG_SZ, REG_EXPAND_SZ
        data = data.encode(WCHAR)
        termsize = WCHAR_SIZE
      when REG_MULTI_SZ
        data = data.to_a.map {|s| s.encode(WCHAR)}.join(WCHAR_NUL) << WCHAR_NUL
        termsize = WCHAR_SIZE
      when REG_BINARY
        data = data.to_s
      when REG_DWORD
        data = API.packdw(data.to_i)
      when REG_DWORD_BIG_ENDIAN
        data = [data.to_i].pack('N')
      when REG_QWORD
        data = API.packqw(data.to_i)
      else
        raise TypeError, "Unsupported type #{type}"
      end
      API.SetValue(@hkey, name, type, data, data.bytesize + termsize)
    end

    def []=(name, rtype, value = nil)
      if value
        write name, rtype, value
      else
        case value = rtype
        when Integer
          write name, REG_DWORD, value
        when String
          write name, REG_SZ, value
        when Array
          write name, REG_MULTI_SZ, value
        else
          raise TypeError, "Unexpected type #{value.class}"
        end
      end
      value
    end

    def write_s(name, value)
      write name, REG_SZ, value.to_s
    end

    def write_i(name, value)
      write name, REG_DWORD, value.to_i
    end

    def write_bin(name, value)
      write name, REG_BINARY, value.to_s
    end

    def delete_value(name)
      API.DeleteValue(@hkey, name)
    end
    alias delete delete_value

    def delete_key(name, recursive = false)
      if recursive
        open(name, KEY_ALL_ACCESS) do |reg|
          reg.keys.each do |key|
            begin
              reg.delete_key(key, true)
            rescue Error
            end
          end
        end
        API.DeleteKey(@hkey, name)
      else
        begin
          API.EnumKey @hkey, 0
        rescue Error
          return API.DeleteKey(@hkey, name)
        end
        raise Error.new(5) ## ERROR_ACCESS_DENIED
      end
    end

    def flush
      API.FlushKey @hkey
    end

    def info
      API.QueryInfoKey(@hkey)
    end

    %w[
      num_keys max_key_length
      num_values max_value_name_length max_value_length
      descriptor_length wtime
    ].each_with_index do |s, i|
      #nodyna <eval-1517> <EV MODERATE (method definition)>
      eval <<-__END__
        def #{s}
          info[#{i}]
        end
      __END__
    end

    private

    def export_string(str, enc = Encoding.default_internal || LOCALE) # :nodoc:
      str.encode(enc)
    end
  end
end
