begin
  require 'openssl'
rescue LoadError
end

module SecureRandom
  if !defined?(OpenSSL::Random) && /mswin|mingw/ =~ RUBY_PLATFORM
    require "fiddle/import"

    module AdvApi32 # :nodoc:
      extend Fiddle::Importer
      dlload "advapi32"
      extern "int CryptAcquireContext(void*, void*, void*, unsigned long, unsigned long)"
      extern "int CryptGenRandom(void*, unsigned long, void*)"

      def self.get_provider
        hProvStr = " " * Fiddle::SIZEOF_VOIDP
        prov_rsa_full = 1
        crypt_verifycontext = 0xF0000000

        if CryptAcquireContext(hProvStr, nil, nil, prov_rsa_full, crypt_verifycontext) == 0
          raise SystemCallError, "CryptAcquireContext failed: #{lastWin32ErrorMessage}"
        end
        type = Fiddle::SIZEOF_VOIDP == Fiddle::SIZEOF_LONG_LONG ? 'q' : 'l'
        hProv, = hProvStr.unpack(type)
        hProv
      end

      def self.gen_random(n)
        @hProv ||= get_provider
        bytes = " ".force_encoding("ASCII-8BIT") * n
        if CryptGenRandom(@hProv, bytes.size, bytes) == 0
          raise SystemCallError, "CryptGenRandom failed: #{Kernel32.last_error_message}"
        end
        bytes
      end
    end

    module Kernel32 # :nodoc:
      extend Fiddle::Importer
      dlload "kernel32"
      extern "unsigned long GetLastError()"
      extern "unsigned long FormatMessageA(unsigned long, void*, unsigned long, unsigned long, void*, unsigned long, void*)"

      def self.last_error_message
        format_message_ignore_inserts = 0x00000200
        format_message_from_system    = 0x00001000

        code = GetLastError()
        msg = "\0" * 1024
        len = FormatMessageA(format_message_ignore_inserts + format_message_from_system, 0, code, 0, msg, 1024, nil)
        msg[0, len].force_encoding("filesystem").tr("\r", '').chomp
      end
    end
  end

  def self.random_bytes(n=nil)
    n = n ? n.to_int : 16
    gen_random(n)
  end

  if defined? OpenSSL::Random
    def self.gen_random(n)
      @pid = 0 unless defined?(@pid)
      pid = $$
      unless @pid == pid
        now = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
        ary = [now, @pid, pid]
        OpenSSL::Random.random_add(ary.join("").to_s, 0.0)
        @pid = pid
      end
      return OpenSSL::Random.random_bytes(n)
    end
  elsif defined?(AdvApi32)
    def self.gen_random(n)
      return AdvApi32.gen_random(n)
    end

    def self.lastWin32ErrorMessage # :nodoc:
      return Kernel32.last_error_message
    end
  else
    def self.gen_random(n)
      flags = File::RDONLY
      flags |= File::NONBLOCK if defined? File::NONBLOCK
      flags |= File::NOCTTY if defined? File::NOCTTY
      begin
        File.open("/dev/urandom", flags) {|f|
          unless f.stat.chardev?
            break
          end
          ret = f.read(n)
          unless ret.length == n
            raise NotImplementedError, "Unexpected partial read from random device: only #{ret.length} for #{n} bytes"
          end
          return ret
        }
      rescue Errno::ENOENT
      end

      raise NotImplementedError, "No random device"
    end
  end

  def self.hex(n=nil)
    random_bytes(n).unpack("H*")[0]
  end

  def self.base64(n=nil)
    [random_bytes(n)].pack("m*").delete("\n")
  end

  def self.urlsafe_base64(n=nil, padding=false)
    s = [random_bytes(n)].pack("m*")
    s.delete!("\n")
    s.tr!("+/", "-_")
    s.delete!("=") unless padding
    s
  end

  def self.random_number(n=0)
    if 0 < n
      if defined? OpenSSL::BN
        OpenSSL::BN.rand_range(n).to_i
      else
        hex = n.to_s(16)
        hex = '0' + hex if (hex.length & 1) == 1
        bin = [hex].pack("H*")
        mask = bin[0].ord
        mask |= mask >> 1
        mask |= mask >> 2
        mask |= mask >> 4
        begin
          rnd = SecureRandom.random_bytes(bin.length)
          rnd[0] = (rnd[0].ord & mask).chr
        end until rnd < bin
        rnd.unpack("H*")[0].hex
      end
    else
      if defined? OpenSSL::BN
        i64 = OpenSSL::BN.rand(64, -1).to_i
      else
        i64 = SecureRandom.random_bytes(8).unpack("Q")[0]
      end
      Math.ldexp(i64 >> (64-Float::MANT_DIG), -Float::MANT_DIG)
    end
  end

  def self.uuid
    ary = self.random_bytes(16).unpack("NnnnnN")
    ary[2] = (ary[2] & 0x0fff) | 0x4000
    ary[3] = (ary[3] & 0x3fff) | 0x8000
    "%08x-%04x-%04x-%04x-%04x%08x" % ary
  end
end
