require 'digest.so'

module Digest
  REQUIRE_MUTEX = Mutex.new

  def self.const_missing(name) # :nodoc:
    case name
    when :SHA256, :SHA384, :SHA512
      lib = 'digest/sha2.so'
    else
      lib = File.join('digest', name.to_s.downcase)
    end

    begin
      require lib
    rescue LoadError
      raise LoadError, "library not found for class Digest::#{name} -- #{lib}", caller(1)
    end
    unless Digest.const_defined?(name)
      raise NameError, "uninitialized constant Digest::#{name}", caller(1)
    end
    #nodyna <const_get-1520> <CG COMPLEX (change-prone variable)>
    Digest.const_get(name)
  end

  class ::Digest::Class
    def self.file(name, *args)
      new(*args).file(name)
    end

    def self.base64digest(str, *args)
      [digest(str, *args)].pack('m0')
    end
  end

  module Instance
    def file(name)
      File.open(name, "rb") {|f|
        buf = ""
        while f.read(16384, buf)
          update buf
        end
      }
      self
    end

    def base64digest(str = nil)
      [str ? digest(str) : digest].pack('m0')
    end

    def base64digest!
      [digest!].pack('m0')
    end
  end
end

def Digest(name)
  const = name.to_sym
  Digest::REQUIRE_MUTEX.synchronize {
    Digest.const_missing(const)
  }
rescue LoadError
  if Digest.const_defined?(const)
    #nodyna <const_get-1521> <CG COMPLEX (change-prone variable)>
    Digest.const_get(const)
  else
    raise
  end
end
